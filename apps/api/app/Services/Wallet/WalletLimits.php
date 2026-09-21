<?php

namespace App\Services\Wallet;

use App\Enums\WalletOperation;
use App\Enums\WalletStatus;
use App\Exceptions\DomainRuleException;
use App\Models\User;
use App\Models\WalletTransaction;

/**
 * Plafonds et garde-fous du portefeuille.
 *
 * Le niveau se gagne : un compte neuf est bridé, un compte qui a de l'ancienneté et des
 * opérations réussies monte tout seul, un compte dont la pièce d'identité a été contrôlée
 * passe au niveau le plus haut.
 */
final class WalletLimits
{
    public static function level(User $user): int
    {
        if ($user->wallet_verified_at !== null) {
            return 2;
        }

        $rule = config('wallet.level_one');
        $oldEnough = $user->created_at !== null && $user->created_at->lte(now()->subDays($rule['days']));

        if (! $oldEnough) {
            return 0;
        }

        $operations = WalletTransaction::where('user_id', $user->id)
            ->where('status', WalletStatus::Succeeded)
            ->count();

        return $operations >= $rule['operations'] ? 1 : 0;
    }

    /** @return array{level: int, balance: int, daily_withdrawal: int} */
    public static function forUser(User $user): array
    {
        $level = self::level($user);
        $limits = config('wallet.levels')[$level];

        return ['level' => $level, 'balance' => $limits['balance'], 'daily_withdrawal' => $limits['daily_withdrawal']];
    }

    /** Un solde ne dépasse pas le plafond du niveau : le trop-perçu doit être retiré d'abord. */
    public static function ensureCanReceive(User $user, int $amount, int $currentBalance): void
    {
        $limits = self::forUser($user);

        if ($currentBalance + $amount > $limits['balance']) {
            $max = number_format($limits['balance'], 0, ',', ' ');
            throw new DomainRuleException(
                "Votre solde ne peut pas dépasser {$max} FCFA. Retirez une partie de votre argent avant de recevoir plus.",
            );
        }
    }

    public static function ensureCanWithdraw(User $user, int $amount): void
    {
        $limits = self::forUser($user);

        $today = (int) WalletTransaction::where('user_id', $user->id)
            ->where('type', WalletOperation::Withdrawal)
            ->whereIn('status', [WalletStatus::Pending, WalletStatus::Succeeded])
            ->where('created_at', '>=', now()->startOfDay())
            ->sum('amount');

        if ($today + $amount > $limits['daily_withdrawal']) {
            $max = number_format($limits['daily_withdrawal'], 0, ',', ' ');
            throw new DomainRuleException("Vous ne pouvez pas retirer plus de {$max} FCFA par jour.");
        }
    }

    /** Dix opérations en dix minutes, c'est un automate, pas une personne qui cotise. */
    public static function ensureNotTooFast(User $user): void
    {
        $velocity = config('wallet.velocity');

        $recent = WalletTransaction::where('user_id', $user->id)
            ->where('created_at', '>=', now()->subMinutes($velocity['minutes']))
            ->count();

        if ($recent >= $velocity['operations']) {
            throw new DomainRuleException('Trop d’opérations en peu de temps. Patientez quelques minutes.');
        }
    }
}
