<?php

namespace App\Services;

use App\Enums\CagnotteStatus;
use App\Enums\FeeOperation;
use App\Enums\FeePayer;
use App\Enums\PaymentMethod;
use App\Enums\PaymentStatus;
use App\Exceptions\DomainRuleException;
use App\Models\Cagnotte;
use App\Models\Contribution;
use App\Models\Payment;
use App\Models\User;
use App\Services\Fees\FeeEngine;
use App\Services\Fees\FeeQuote;
use App\Services\PayDunya\PayDunyaClient;
use App\Services\Wallet\WalletService;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;

/**
 * Paiements en ligne. PayDunya est la seule source de vérité : le statut est toujours relu
 * auprès de son API (jamais pris dans la notification), et l'effet n'est appliqué qu'une fois.
 */
class PaymentService
{
    public function __construct(private PayDunyaClient $client, private FeeEngine $fees, private WalletService $wallet) {}

    public function startForContribution(Contribution $contribution, User $payer): Payment
    {
        $contribution->loadMissing('cycle.tontine');

        if ($contribution->confirmed_at !== null || $contribution->amount_paid >= $contribution->amount_due) {
            throw new DomainRuleException('Cette cotisation est déjà réglée.');
        }

        $tontine = $contribution->cycle->tontine;
        $quote = $this->fees->quote(
            FeeOperation::ContributionOnline,
            $contribution->amount_due - $contribution->amount_paid,
            $tontine->organization_id,
        );

        return $this->start(
            $contribution,
            $payer,
            $tontine->organization_id,
            $quote,
            "Cotisation {$tontine->name}, tour {$contribution->cycle->number}",
        );
    }

    public function startForCagnotte(Cagnotte $cagnotte, User $payer, int $amount): Payment
    {
        if (! $cagnotte->acceptsContributions()) {
            throw new DomainRuleException('Cette cagnotte est clôturée, elle n’accepte plus de participation.');
        }

        // Le ticket est encaissé au franc près : la part de la plateforme est retenue sur le pot
        // au moment du partage, jamais ajoutée au prix payé par le participant.
        $quote = new FeeQuote(FeeOperation::PrizePool, $amount, 0, FeePayer::Beneficiary);

        return $this->start($cagnotte, $payer, $cagnotte->organization_id, $quote, "Participation à {$cagnotte->title}");
    }

    public function refresh(Payment $payment): Payment
    {
        if ($payment->status !== PaymentStatus::Pending || $payment->token === null) {
            return $payment;
        }

        return $this->apply($payment, $this->client->confirmInvoice($payment->token));
    }

    /** @param  array  $invoice  réponse de checkout-invoice/confirm */
    public function apply(Payment $payment, array $invoice): Payment
    {
        return DB::transaction(function () use ($payment, $invoice) {
            $payment = Payment::whereKey($payment->id)->lockForUpdate()->firstOrFail();
            $status = $invoice['status'] ?? 'pending';

            if ($payment->status !== PaymentStatus::Pending || $status === 'pending') {
                return $payment;
            }

            if ($status !== 'completed') {
                $payment->update([
                    'status' => $status === 'cancelled' ? PaymentStatus::Cancelled : PaymentStatus::Failed,
                    'failure_reason' => $invoice['fail_reason'] ?? null,
                    'payload' => $invoice,
                ]);

                return $payment;
            }

            if ((int) data_get($invoice, 'invoice.total_amount') !== $payment->amount) {
                Log::warning('PayDunya : montant payé différent du montant attendu', ['payment' => $payment->id]);
                $payment->update(['status' => PaymentStatus::Failed, 'failure_reason' => 'Montant payé différent du montant attendu.', 'payload' => $invoice]);

                return $payment;
            }

            $payment->update([
                'status' => PaymentStatus::Paid,
                'paid_at' => now(),
                'receipt_url' => $invoice['receipt_url'] ?? null,
                'payload' => $invoice,
            ]);

            $this->chargeFee($payment);

            $payable = $payment->payable;
            $applied = match (true) {
                $payable instanceof Contribution => $this->applyToContribution($payable, $payment),
                $payable instanceof Cagnotte => $this->applyToCagnotte($payable, $payment),
                $payable instanceof User => $this->wallet->applyDeposit($payable, $payment),
                default => false,
            };

            if ($applied) {
                $payment->update(['applied_at' => now()]);
            } else {
                // L'argent est bien reçu : le trésorier doit le rapprocher ou le rembourser.
                Log::warning('PayDunya : paiement reçu mais non affecté', ['payment' => $payment->id]);
            }

            return $payment;
        });
    }

    public function start(Model $payable, User $payer, ?int $organizationId, FeeQuote $quote, string $description): Payment
    {
        $payment = Payment::create([
            'organization_id' => $organizationId,
            'user_id' => $payer->id,
            'payable_type' => $payable->getMorphClass(),
            'payable_id' => $payable->getKey(),
            'amount' => $quote->total(),
            'base_amount' => $quote->base,
            'fee_amount' => $quote->fee,
            'fee_operation' => $quote->operation,
            'fee_rule_id' => $quote->rule?->id,
        ]);

        try {
            $invoice = $this->client->createInvoice($payment->amount, $description, ['payment_id' => $payment->id], [
                'return_url' => route('payments.return', ['paiement' => $payment->id]),
                'cancel_url' => route('payments.return', ['paiement' => $payment->id, 'annule' => 1]),
                'callback_url' => route('payments.paydunya.ipn'),
            ]);
        } catch (DomainRuleException $exception) {
            $payment->update(['status' => PaymentStatus::Failed, 'failure_reason' => 'Facture non créée.']);

            throw $exception;
        }

        $payment->update(['token' => $invoice['token'], 'checkout_url' => $invoice['url']]);

        return $payment;
    }

    /** Les frais ne sont inscrits qu'une fois l'argent réellement reçu. */
    private function chargeFee(Payment $payment): void
    {
        // Le dépôt inscrit ses frais lui-même, avec l'écriture qui crédite le solde.
        if ($payment->fee_amount <= 0 || $payment->fee_operation === null || $payment->fee_operation === FeeOperation::Deposit) {
            return;
        }

        $this->fees->charge(
            new FeeQuote(
                operation: $payment->fee_operation,
                base: $payment->base_amount,
                fee: $payment->fee_amount,
                payer: FeePayer::Payer,
                rule: $payment->feeRule,
            ),
            $payment,
            $payment->user_id,
            $payment->organization_id,
        );
    }

    /** Le membre a payé lui-même par PayDunya : la cotisation est confirmée dès qu'elle est complète. */
    private function applyToContribution(Contribution $contribution, Payment $payment): bool
    {
        $contribution = Contribution::whereKey($contribution->id)->lockForUpdate()->firstOrFail();

        if ($contribution->confirmed_at !== null || $contribution->amount_paid >= $contribution->amount_due) {
            return false;
        }

        // Seule la cotisation elle-même est affectée : les frais de service n'entrent pas dans le tour.
        $paid = min($contribution->amount_due, $contribution->amount_paid + $payment->base_amount);

        $contribution->update([
            'amount_paid' => $paid,
            'method' => PaymentMethod::PayDunya,
            'reference' => $payment->token,
            'paid_at' => now(),
            'recorded_by' => $payment->user_id,
            'confirmed_at' => $paid >= $contribution->amount_due ? now() : null,
        ]);

        $contribution->cycle->tontine->refreshCompletion();

        return true;
    }

    /** Participation créée et confirmée, avec ses tickets, tant que le tirage n'est pas lancé. */
    private function applyToCagnotte(Cagnotte $cagnotte, Payment $payment): bool
    {
        $cagnotte = Cagnotte::whereKey($cagnotte->id)->lockForUpdate()->firstOrFail();

        if ($cagnotte->draw_seed_hash !== null || in_array($cagnotte->status, [CagnotteStatus::HandedOver, CagnotteStatus::Drawn, CagnotteStatus::Cancelled], true)) {
            return false;
        }

        $cagnotte->contributions()->create([
            'organization_id' => $cagnotte->organization_id,
            'user_id' => $payment->user_id,
            'amount' => $payment->base_amount,
            'tickets' => $cagnotte->ticketsFor($payment->base_amount),
            'method' => PaymentMethod::PayDunya,
            'reference' => $payment->token,
            'paid_at' => now(),
            'recorded_by' => $payment->user_id,
            'confirmed_at' => now(),
        ]);

        return true;
    }
}
