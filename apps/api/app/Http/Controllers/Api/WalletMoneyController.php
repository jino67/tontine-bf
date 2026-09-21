<?php

namespace App\Http\Controllers\Api;

use App\Enums\FeeOperation;
use App\Exceptions\DomainRuleException;
use App\Http\Controllers\Controller;
use App\Http\Resources\PaymentResource;
use App\Http\Resources\WalletTransactionResource;
use App\Models\User;
use App\Services\Fees\FeeEngine;
use App\Services\PaymentService;
use App\Services\PayoutService;
use App\Services\Wallet\WalletLimits;
use App\Services\Wallet\WalletService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * Les deux seules portes par lesquelles l'argent entre et sort du portefeuille.
 *
 * Le dépôt reste fermé tant que WALLET_DEPOSITS_ENABLED vaut false : conserver le solde
 * d'un public est une activité réglementée par la BCEAO, et l'ouvrir se décide avec un
 * cadrage juridique écrit, pas avec une ligne de code oubliée.
 */
class WalletMoneyController extends Controller
{
    public function __construct(
        private WalletService $wallet,
        private FeeEngine $fees,
        private PaymentService $payments,
        private PayoutService $payouts,
    ) {}

    public function deposit(Request $request): JsonResponse
    {
        if (! config('wallet.deposits_enabled')) {
            throw new DomainRuleException(
                'Le dépôt libre n’est pas encore ouvert. Votre solde se garnit avec vos gains, '
                .'vos tours reçus et les remboursements.',
            );
        }

        $data = $request->validate([
            'amount' => ['required', 'integer', 'min:'.config('wallet.min_deposit'), 'max:1000000'],
        ]);

        $user = $request->user();
        $amount = (int) $data['amount'];
        $quote = $this->fees->quote(FeeOperation::Deposit, $amount);

        WalletLimits::ensureCanReceive($user, $amount, $this->wallet->balance($user));

        $payment = $this->payments->start($user, $user, null, $quote, 'Dépôt sur le portefeuille Tontine BF');

        return PaymentResource::make($payment)->response()->setStatusCode(201);
    }

    public function withdraw(Request $request): JsonResponse
    {
        $data = $request->validate([
            'amount' => ['required', 'integer', 'min:'.config('wallet.min_withdrawal'), 'max:1000000'],
        ]);

        $user = $request->user();
        $this->ensurePayoutPhoneUsable($user);

        $transaction = $this->wallet->startWithdrawal($user, (int) $data['amount']);

        try {
            $this->payouts->send(
                $transaction,
                null,
                $user,
                $transaction->amount,
                $user->payout_phone,
                $user->payout_mode,
                $user->id,
            );
        } catch (DomainRuleException $exception) {
            $this->wallet->failWithdrawal($transaction, $exception->getMessage());

            throw $exception;
        }

        return WalletTransactionResource::make($transaction->refresh())->response()->setStatusCode(201);
    }

    /** Un numéro fraîchement changé attend le délai de sécurité avant de servir. */
    private function ensurePayoutPhoneUsable(User $user): void
    {
        if ($user->payout_phone === null || $user->payout_mode === null) {
            throw new DomainRuleException('Enregistrez d’abord le numéro mobile money qui recevra l’argent.');
        }

        $delay = (int) config('wallet.payout_change_delay_hours');
        $changed = $user->payout_changed_at;

        if ($user->payout_phone !== $user->phone && $changed !== null && $changed->gt(now()->subHours($delay))) {
            $hours = (int) ceil(now()->diffInHours($changed->copy()->addHours($delay), false));
            throw new DomainRuleException(
                "Ce numéro de retrait vient d’être changé. Le premier retrait sera possible dans {$hours} h.",
            );
        }
    }
}
