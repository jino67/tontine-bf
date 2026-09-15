<?php

namespace App\Services;

use App\Enums\CagnotteStatus;
use App\Enums\PaymentMethod;
use App\Enums\PayoutStatus;
use App\Exceptions\DomainRuleException;
use App\Models\Cagnotte;
use App\Models\CagnotteWinner;
use App\Models\Payout;
use App\Models\User;
use App\Services\PayDunya\PayDunyaClient;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Str;

/** Remises par PayDunya : gain d'une cagnotte à gagnants ou fonds d'une cagnotte solidaire. */
class PayoutService
{
    /** Opérateurs acceptés par l'API de déboursement PayDunya. */
    public const WITHDRAW_MODES = [
        'orange-money-burkina', 'moov-burkina-faso',
        'orange-money-ci', 'mtn-ci', 'moov-ci', 'wave-ci',
        'orange-money-senegal', 'free-money-senegal', 'wave-senegal',
        'orange-money-mali', 'mtn-benin', 'moov-benin', 't-money-togo', 'moov-togo',
    ];

    public function __construct(private PayDunyaClient $client) {}

    public static function ensureNoneInProgress(Model $payable): void
    {
        $inProgress = Payout::where('payable_type', $payable->getMorphClass())
            ->where('payable_id', $payable->getKey())
            ->where('status', PayoutStatus::Processing)
            ->exists();

        if ($inProgress) {
            throw new DomainRuleException('Une remise PayDunya est déjà en cours. Attendez son résultat.');
        }
    }

    public function send(Model $payable, int $organizationId, User $initiator, int $amount, string $phone, string $withdrawMode, ?int $recipientId): Payout
    {
        if (! config('services.paydunya.payouts_enabled')) {
            throw new DomainRuleException('Les remises par PayDunya ne sont pas activées sur ce serveur. Enregistrez une remise manuelle.');
        }

        if ($amount <= 0) {
            throw new DomainRuleException('Il n’y a aucun montant à remettre.');
        }

        self::ensureNoneInProgress($payable);

        $payout = Payout::create([
            'organization_id' => $organizationId,
            'payable_type' => $payable->getMorphClass(),
            'payable_id' => $payable->getKey(),
            'user_id' => $recipientId,
            'phone' => self::localPhone($phone),
            'withdraw_mode' => $withdrawMode,
            'amount' => $amount,
            'disburse_id' => 'TBF-'.Str::upper(Str::random(16)),
            'initiated_by' => $initiator->id,
        ]);

        try {
            $result = $this->client->disburse($payout->phone, $amount, $withdrawMode, route('payouts.paydunya.callback'), $payout->disburse_id);
        } catch (DomainRuleException $exception) {
            $payout->update(['status' => PayoutStatus::Failed, 'failure_reason' => $exception->getMessage()]);

            throw $exception;
        }

        $payout->update(['token' => $result['token'], 'payload' => $result['body']]);

        return $this->apply($payout, $result['body']);
    }

    public function refresh(Payout $payout): Payout
    {
        if ($payout->status !== PayoutStatus::Processing || $payout->token === null) {
            return $payout;
        }

        return $this->apply($payout, $this->client->disburseStatus($payout->token));
    }

    /** @param  array  $data  réponse de submit-invoice ou de check-status */
    public function apply(Payout $payout, array $data): Payout
    {
        return DB::transaction(function () use ($payout, $data) {
            $payout = Payout::whereKey($payout->id)->lockForUpdate()->firstOrFail();
            $status = $data['status'] ?? (($data['response_code'] ?? null) === '00' ? 'pending' : 'failed');

            if ($payout->status !== PayoutStatus::Processing || in_array($status, ['created', 'pending'], true)) {
                return $payout;
            }

            if ($status !== 'success') {
                $payout->update(['status' => PayoutStatus::Failed, 'failure_reason' => $data['response_text'] ?? null, 'payload' => $data]);

                return $payout;
            }

            $reference = $data['transaction_id'] ?? $payout->token;
            $payout->update([
                'status' => PayoutStatus::Succeeded,
                'transaction_id' => $data['transaction_id'] ?? null,
                'completed_at' => now(),
                'payload' => $data,
            ]);

            $payable = $payout->payable;

            if ($payable instanceof CagnotteWinner && $payable->paid_at === null) {
                $payable->update([
                    'paid_at' => now(),
                    'paid_method' => PaymentMethod::PayDunya,
                    'paid_reference' => $reference,
                    'paid_by' => $payout->initiated_by,
                ]);
            } elseif ($payable instanceof Cagnotte && $payable->status !== CagnotteStatus::HandedOver) {
                $payable->update([
                    'status' => CagnotteStatus::HandedOver,
                    'closed_at' => $payable->closed_at ?? $payable->ends_at,
                    'handover_amount' => $payout->amount,
                    'handover_method' => PaymentMethod::PayDunya,
                    'handover_reference' => $reference,
                    'handed_over_at' => now(),
                    'handover_recorded_by' => $payout->initiated_by,
                ]);
            } else {
                Log::warning('PayDunya : remise réussie sur un élément déjà marqué remis', ['payout' => $payout->id]);
            }

            return $payout;
        });
    }

    /** « 70 12 34 56 » ou « +226 70 12 34 56 » deviennent « 70123456 » : PayDunya attend le numéro sans indicatif. */
    public static function localPhone(string $phone): string
    {
        $digits = preg_replace('/\D/', '', $phone);

        foreach (['226', '225', '221', '223', '229', '228'] as $prefix) {
            if (str_starts_with($digits, '00'.$prefix)) {
                return substr($digits, 5);
            }
            if (str_starts_with($digits, $prefix) && strlen($digits) > 10) {
                return substr($digits, 3);
            }
        }

        return $digits;
    }
}
