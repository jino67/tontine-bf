<?php

namespace App\Services\Wallet;

use App\Enums\AccountKind;
use App\Enums\FeeOperation;
use App\Enums\FeePayer;
use App\Enums\LedgerDirection;
use App\Enums\PaymentMethod;
use App\Enums\WalletOperation;
use App\Enums\WalletStatus;
use App\Exceptions\DomainRuleException;
use App\Models\Account;
use App\Models\Cagnotte;
use App\Models\Contribution;
use App\Models\Cycle;
use App\Models\Payment;
use App\Models\Payout;
use App\Models\User;
use App\Models\WalletTransaction;
use App\Services\Fees\FeeEngine;
use App\Services\Fees\FeeQuote;
use App\Services\Notifications\NotificationEvents;
use Illuminate\Database\Eloquent\Collection;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

/**
 * Portefeuille des membres.
 *
 * Rien n'est jamais ajouté ni retiré à un solde directement : chaque mouvement passe par
 * le grand livre, et le solde se relit ensuite. Toute opération qui débite un membre
 * vérifie d'abord, sous verrou, qu'il a réellement la somme.
 */
class WalletService
{
    public function __construct(private Ledger $ledger, private FeeEngine $fees, private NotificationEvents $events) {}

    public function account(User $user): Account
    {
        return Account::of($user);
    }

    public function balance(User $user): int
    {
        return $this->account($user)->balance();
    }

    /** @return array<string, mixed> */
    public function summary(User $user): array
    {
        $limits = WalletLimits::forUser($user);

        return [
            'balance' => $this->balance($user),
            'level' => $limits['level'],
            'max_balance' => $limits['balance'],
            'daily_withdrawal' => $limits['daily_withdrawal'],
            'deposits_enabled' => (bool) config('wallet.deposits_enabled'),
            'min_deposit' => (int) config('wallet.min_deposit'),
            'min_withdrawal' => (int) config('wallet.min_withdrawal'),
            'payout_phone' => $user->payout_phone,
            'payout_mode' => $user->payout_mode,
        ];
    }

    /** @return Collection<int, WalletTransaction> */
    public function history(User $user, int $limit = 50): Collection
    {
        return WalletTransaction::where('user_id', $user->id)
            ->with(['counterparty', 'payout'])
            ->latest('id')
            ->limit($limit)
            ->get();
    }

    /** Cotisation réglée avec l'argent déjà présent sur le solde. */
    public function payContribution(Contribution $contribution, User $payer): WalletTransaction
    {
        $contribution->loadMissing('cycle.tontine');
        $tontine = $contribution->cycle->tontine;

        if ($contribution->confirmed_at !== null || $contribution->amount_paid >= $contribution->amount_due) {
            throw new DomainRuleException('Cette cotisation est déjà réglée.');
        }

        $amount = $contribution->amount_due - $contribution->amount_paid;
        $quote = $this->fees->quote(FeeOperation::ContributionWallet, $amount, $tontine->organization_id);

        return DB::transaction(function () use ($contribution, $payer, $tontine, $amount, $quote) {
            $this->ensureFunded($payer, $quote->total());

            $reference = $this->ledger->move(
                $this->account($payer),
                Account::of($tontine->organization),
                $amount,
                $quote->fee,
                $contribution,
                "Cotisation {$tontine->name}, tour {$contribution->cycle->number}",
            );

            $paid = $contribution->amount_paid + $amount;
            $contribution->update([
                'amount_paid' => $paid,
                'method' => PaymentMethod::Wallet,
                'reference' => $reference,
                'paid_at' => now(),
                'recorded_by' => $payer->id,
                'confirmed_at' => now(),
            ]);
            $tontine->refreshCompletion();

            $this->fees->charge($quote, $contribution, $payer->id, $tontine->organization_id);

            return $this->record($payer, WalletOperation::Contribution, $amount, $quote->fee, [
                'reference' => $reference,
                'organization_id' => $tontine->organization_id,
                'related' => $contribution,
                'description' => "Cotisation {$tontine->name}, tour {$contribution->cycle->number}",
            ]);
        });
    }

    /** Participation à une cagnotte réglée depuis le solde. */
    public function participate(Cagnotte $cagnotte, User $payer, int $amount): WalletTransaction
    {
        if (! $cagnotte->acceptsContributions()) {
            throw new DomainRuleException('Cette cagnotte est clôturée, elle n’accepte plus de participation.');
        }

        return DB::transaction(function () use ($cagnotte, $payer, $amount) {
            $this->ensureFunded($payer, $amount);

            $reference = $this->ledger->move(
                $this->account($payer),
                Account::of($cagnotte),
                $amount,
                0,
                $cagnotte,
                "Participation à {$cagnotte->title}",
            );

            $cagnotte->contributions()->create([
                'organization_id' => $cagnotte->organization_id,
                'user_id' => $payer->id,
                'amount' => $amount,
                'tickets' => $cagnotte->ticketsFor($amount),
                'method' => PaymentMethod::Wallet,
                'reference' => $reference,
                'paid_at' => now(),
                'recorded_by' => $payer->id,
                'confirmed_at' => now(),
            ]);

            return $this->record($payer, WalletOperation::Participation, $amount, 0, [
                'reference' => $reference,
                'organization_id' => $cagnotte->organization_id,
                'related' => $cagnotte,
                'description' => "Participation à {$cagnotte->title}",
            ]);
        });
    }

    /** Envoi d'argent à un autre membre, de solde à solde. Gratuit : rien ne sort de la plateforme. */
    public function transfer(User $from, User $to, int $amount, ?string $note = null): WalletTransaction
    {
        if ($from->id === $to->id) {
            throw new DomainRuleException('Vous ne pouvez pas vous envoyer de l’argent à vous-même.');
        }

        $quote = $this->fees->quote(FeeOperation::Transfer, $amount);

        return DB::transaction(function () use ($from, $to, $amount, $note, $quote) {
            $this->ensureFunded($from, $quote->total());
            WalletLimits::ensureCanReceive($to, $amount, $this->balance($to));

            $reference = $this->ledger->move($this->account($from), $this->account($to), $amount, $quote->fee, null, $note);

            $received = $this->record($to, WalletOperation::TransferIn, $amount, 0, [
                'reference' => $reference.'-R',
                'counterparty_user_id' => $from->id,
                'description' => $note ?? 'Reçu de '.($from->name ?? 'un membre'),
            ]);
            $this->events->walletCredited($to, $received);

            return $this->record($from, WalletOperation::TransferOut, $amount, $quote->fee, [
                'reference' => $reference,
                'counterparty_user_id' => $to->id,
                'description' => $note ?? 'Envoyé à '.($to->name ?? 'un membre'),
            ]);
        });
    }

    /**
     * Crédit d'un gain, d'un tour ou des fonds d'une cagnotte, pris sur le compte qui les détient.
     * Les frais de remise sont retenus au passage.
     */
    public function creditFrom(
        Model $source,
        User $user,
        WalletOperation $type,
        int $amount,
        ?FeeOperation $feeOperation = null,
        ?Model $related = null,
        ?string $description = null,
        ?int $organizationId = null,
    ): WalletTransaction {
        // Sans opération de frais, le mouvement est gratuit : rien ne sort de la plateforme.
        $quote = $feeOperation === null
            ? new FeeQuote(FeeOperation::Transfer, $amount, 0, FeePayer::Beneficiary)
            : $this->fees->quote($feeOperation, $amount, $organizationId);
        $net = $quote->net();

        return DB::transaction(function () use ($source, $user, $type, $amount, $net, $quote, $related, $description, $organizationId) {
            $this->ensureHolds($source, $amount);
            WalletLimits::ensureCanReceive($user, $net, $this->balance($user));

            $reference = $this->ledger->move(
                Account::of($source),
                $this->account($user),
                $net,
                $quote->fee,
                $related,
                $description,
            );

            $this->fees->charge($quote, $related, $user->id, $organizationId);

            $credited = $this->record($user, $type, $net, $quote->fee, [
                'reference' => $reference,
                'organization_id' => $organizationId,
                'related' => $related,
                'description' => $description,
            ]);
            $this->events->walletCredited($user, $credited);

            return $credited;
        });
    }

    /** Dépôt : l'argent est arrivé chez PayDunya, le solde du membre monte d'autant. */
    public function applyDeposit(User $user, Payment $payment): bool
    {
        if (WalletTransaction::where('payment_id', $payment->id)->exists()) {
            return false;
        }

        DB::transaction(function () use ($user, $payment) {
            $reference = $this->ledger->post([
                [
                    'account' => Account::system(AccountKind::Settlement),
                    'direction' => LedgerDirection::Debit,
                    'amount' => $payment->amount,
                    'memo' => 'Dépôt encaissé par PayDunya',
                ],
                [
                    'account' => $this->account($user),
                    'direction' => LedgerDirection::Credit,
                    'amount' => $payment->base_amount,
                    'memo' => 'Dépôt sur le portefeuille',
                ],
                [
                    'account' => Account::system(AccountKind::Revenue),
                    'direction' => LedgerDirection::Credit,
                    'amount' => $payment->fee_amount,
                    'memo' => 'Frais de dépôt',
                ],
            ], $payment);

            $this->record($user, WalletOperation::Deposit, $payment->base_amount, $payment->fee_amount, [
                'reference' => $reference,
                'payment_id' => $payment->id,
                'description' => 'Dépôt depuis mobile money',
            ]);
        });

        return true;
    }

    /**
     * Retrait : la somme quitte le solde tout de suite et attend dans le compte d'attente
     * le résultat de PayDunya. Sans cela, le même argent pourrait être dépensé deux fois.
     */
    public function startWithdrawal(User $user, int $amount): WalletTransaction
    {
        $quote = $this->fees->quote(FeeOperation::Withdrawal, $amount);

        return DB::transaction(function () use ($user, $amount, $quote) {
            $this->ensureFunded($user, $quote->total());
            WalletLimits::ensureCanWithdraw($user, $amount);

            $reference = $this->ledger->move(
                $this->account($user),
                Account::system(AccountKind::Suspense),
                $quote->total(),
                0,
                null,
                'Retrait en cours',
            );

            return $this->record($user, WalletOperation::Withdrawal, $amount, $quote->fee, [
                'reference' => $reference,
                'status' => WalletStatus::Pending,
                'description' => 'Retrait vers '.($user->payout_phone ?? 'mobile money'),
            ]);
        });
    }

    /** PayDunya a payé : l'argent quitte le compte d'attente, les frais deviennent une recette. */
    public function completeWithdrawal(WalletTransaction $transaction, Payout $payout): void
    {
        if ($transaction->status !== WalletStatus::Pending) {
            return;
        }

        DB::transaction(function () use ($transaction, $payout) {
            $this->ledger->post([
                [
                    'account' => Account::system(AccountKind::Suspense),
                    'direction' => LedgerDirection::Debit,
                    'amount' => $transaction->amount + $transaction->fee_amount,
                    'memo' => 'Retrait envoyé',
                ],
                [
                    'account' => Account::system(AccountKind::Settlement),
                    'direction' => LedgerDirection::Credit,
                    'amount' => $transaction->amount,
                    'memo' => 'Reversement mobile money',
                ],
                [
                    'account' => Account::system(AccountKind::Revenue),
                    'direction' => LedgerDirection::Credit,
                    'amount' => $transaction->fee_amount,
                    'memo' => 'Frais de retrait',
                ],
            ], $payout);

            $transaction->update(['status' => WalletStatus::Succeeded, 'payout_id' => $payout->id]);

            $this->fees->charge(
                $this->fees->quote(FeeOperation::Withdrawal, $transaction->amount),
                $payout,
                $transaction->user_id,
            );
        });
    }

    /** Retrait refusé : la somme revient sur le solde, et le motif est consigné. */
    public function failWithdrawal(WalletTransaction $transaction, ?string $reason): void
    {
        if ($transaction->status !== WalletStatus::Pending) {
            return;
        }

        DB::transaction(function () use ($transaction, $reason) {
            $total = $transaction->amount + $transaction->fee_amount;

            $this->ledger->move(
                Account::system(AccountKind::Suspense),
                Account::of($transaction->user),
                $total,
                0,
                null,
                'Retrait refusé, somme rendue',
            );

            $transaction->update([
                'status' => WalletStatus::Failed,
                'failure_reason' => $reason ?? 'Refusé par l’opérateur.',
            ]);
        });
    }

    /** Versement d'un tour au bénéficiaire, pris sur ce que l'organisation détient réellement. */
    public function payCycle(Cycle $cycle, User $beneficiary): WalletTransaction
    {
        $cycle->loadMissing('tontine.organization');
        $organization = $cycle->tontine->organization;

        $already = WalletTransaction::where('type', WalletOperation::CyclePayout)
            ->where('related_type', $cycle->getMorphClass())
            ->where('related_id', $cycle->getKey())
            ->exists();

        if ($already) {
            throw new DomainRuleException('Le versement de ce tour est déjà enregistré.');
        }
        $held = Account::of($organization)->balance();
        $amount = min((int) $cycle->contributions()->sum('amount_paid'), $held);

        if ($amount <= 0) {
            throw new DomainRuleException(
                'Rien à verser : aucune cotisation de ce tour n’a été réglée par l’application.',
            );
        }

        return $this->creditFrom(
            $organization,
            $beneficiary,
            WalletOperation::CyclePayout,
            $amount,
            FeeOperation::CyclePayout,
            $cycle,
            "Tour {$cycle->number} de {$cycle->tontine->name}",
            $organization->id,
        );
    }

    /**
     * Refuse de verser plus que ce que la plateforme détient pour cet objet. La différence
     * vient des cotisations remises en espèces : elles n'ont jamais transité par l'application,
     * et se remettent de la main à la main comme avant.
     */
    private function ensureHolds(Model $source, int $amount): void
    {
        $held = Account::of($source)->balance();

        if ($held < $amount) {
            $available = number_format(max(0, $held), 0, ',', ' ');
            throw new DomainRuleException(
                "L’application ne détient que {$available} FCFA pour cette somme : le reste a été réglé "
                .'en espèces et se remet directement au bénéficiaire.',
            );
        }
    }

    /** Vérifie sous verrou que le solde couvre la somme : deux opérations simultanées ne passent pas. */
    private function ensureFunded(User $user, int $needed): void
    {
        $account = Account::whereKey($this->account($user)->id)->lockForUpdate()->firstOrFail();
        WalletLimits::ensureNotTooFast($user);

        if ($account->balance() < $needed) {
            $missing = number_format($needed - $account->balance(), 0, ',', ' ');
            throw new DomainRuleException("Votre solde est insuffisant : il manque {$missing} FCFA.");
        }
    }

    /** @param  array<string, mixed>  $attributes */
    private function record(User $user, WalletOperation $type, int $amount, int $fee, array $attributes = []): WalletTransaction
    {
        $related = $attributes['related'] ?? null;
        unset($attributes['related']);

        return WalletTransaction::create([
            'reference' => $attributes['reference'] ?? 'TX-'.Str::upper(Str::random(16)),
            'user_id' => $user->id,
            'type' => $type,
            'direction' => $type->direction(),
            'amount' => $amount,
            'fee_amount' => $fee,
            'balance_after' => $this->balance($user),
            'related_type' => $related?->getMorphClass(),
            'related_id' => $related?->getKey(),
            ...$attributes,
        ]);
    }
}
