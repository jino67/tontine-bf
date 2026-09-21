<?php

namespace App\Services\Wallet;

use App\Enums\AccountKind;
use App\Enums\LedgerDirection;
use App\Models\Account;
use App\Models\LedgerEntry;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

/**
 * Grand livre en partie double.
 *
 * Une transaction est refusée si ses écritures ne s'équilibrent pas au franc près.
 * C'est volontairement strict : mieux vaut une erreur visible tout de suite qu'un écart
 * découvert le jour où un membre réclame son argent.
 */
class Ledger
{
    /**
     * Écrit un mouvement complet et retourne sa référence.
     *
     * @param  array<int, array{account: Account, direction: LedgerDirection, amount: int, memo?: string}>  $legs
     */
    public function post(array $legs, ?Model $reference = null, ?string $transactionRef = null): string
    {
        $legs = array_values(array_filter($legs, fn (array $leg) => $leg['amount'] > 0));

        if (count($legs) < 2) {
            throw new \LogicException('Un mouvement demande au moins deux écritures.');
        }

        $debits = $this->total($legs, LedgerDirection::Debit);
        $credits = $this->total($legs, LedgerDirection::Credit);

        if ($debits !== $credits) {
            throw new \LogicException("Écritures déséquilibrées : {$debits} au débit, {$credits} au crédit.");
        }

        $ref = $transactionRef ?? 'TX-'.Str::upper(Str::random(16));

        DB::transaction(function () use ($legs, $reference, $ref) {
            foreach ($legs as $leg) {
                LedgerEntry::create([
                    'transaction_ref' => $ref,
                    'account_id' => $leg['account']->id,
                    'direction' => $leg['direction'],
                    'amount' => $leg['amount'],
                    'reference_type' => $reference?->getMorphClass(),
                    'reference_id' => $reference?->getKey(),
                    'memo' => $leg['memo'] ?? null,
                ]);
            }
        });

        return $ref;
    }

    /**
     * Raccourci du cas courant : une somme passe d'un compte à un autre, la plateforme
     * retenant ses frais au passage.
     *
     * @return string référence du mouvement
     */
    public function move(Account $from, Account $to, int $amount, int $fee = 0, ?Model $reference = null, ?string $memo = null): string
    {
        $legs = [
            ['account' => $from, 'direction' => LedgerDirection::Debit, 'amount' => $amount + $fee, 'memo' => $memo],
            ['account' => $to, 'direction' => LedgerDirection::Credit, 'amount' => $amount, 'memo' => $memo],
        ];

        if ($fee > 0) {
            $legs[] = [
                'account' => Account::system(AccountKind::Revenue),
                'direction' => LedgerDirection::Credit,
                'amount' => $fee,
                'memo' => 'Frais de service',
            ];
        }

        return $this->post($legs, $reference);
    }

    /** @param  array<int, array{direction: LedgerDirection, amount: int}>  $legs */
    private function total(array $legs, LedgerDirection $direction): int
    {
        return array_sum(array_map(
            fn (array $leg) => $leg['direction'] === $direction ? $leg['amount'] : 0,
            $legs,
        ));
    }
}
