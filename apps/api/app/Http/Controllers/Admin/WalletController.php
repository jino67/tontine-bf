<?php

namespace App\Http\Controllers\Admin;

use App\Enums\AccountKind;
use App\Enums\WalletStatus;
use App\Http\Controllers\Controller;
use App\Models\Account;
use App\Models\LedgerEntry;
use App\Models\WalletTransaction;
use App\Services\PayoutService;
use Illuminate\Http\RedirectResponse;
use Illuminate\View\View;

/**
 * Grand livre et retraits.
 *
 * Le contrôle qui compte tient en une ligne : la somme de toutes les écritures doit être
 * nulle. Si elle ne l'est pas, une écriture manque quelque part, et il vaut mieux le savoir
 * avant qu'un membre ne réclame son argent.
 */
class WalletController extends Controller
{
    public function index(): View
    {
        return view('admin.wallet', [
            'balances' => $this->balancesByKind(),
            'systemAccounts' => Account::whereIn('kind', [AccountKind::Revenue, AccountKind::Settlement, AccountKind::Suspense])
                ->get()
                ->map(fn (Account $account) => ['account' => $account, 'balance' => $account->balance()]),
            'pending' => WalletTransaction::with(['user', 'payout'])
                ->where('type', 'retrait')
                ->where('status', WalletStatus::Pending)
                ->latest('id')
                ->get(),
            'entries' => LedgerEntry::with('account')->latest('id')->limit(40)->get(),
            'imbalance' => $this->imbalance(),
        ]);
    }

    /** Relit le statut d'un retrait auprès de PayDunya : utile quand la notification n'arrive pas. */
    public function refresh(WalletTransaction $transaction, PayoutService $payouts): RedirectResponse
    {
        $payout = $transaction->payout;

        if ($payout === null) {
            return back()->with('status', 'Ce retrait n’a pas de remise PayDunya à relire.');
        }

        $payouts->refresh($payout);

        return back()->with('status', 'Statut relu auprès de PayDunya.');
    }

    /** @return array<int, array{kind: AccountKind, accounts: int, balance: int}> */
    private function balancesByKind(): array
    {
        return collect(AccountKind::cases())
            ->map(function (AccountKind $kind) {
                $total = (int) Account::where('accounts.kind', $kind)
                    ->leftJoin('ledger_entries', 'ledger_entries.account_id', '=', 'accounts.id')
                    ->selectRaw("coalesce(sum(case when direction = 'credit' then amount else -amount end), 0) as total")
                    ->value('total');

                return [
                    'kind' => $kind,
                    'accounts' => Account::where('kind', $kind)->count(),
                    'balance' => $kind->isDebitNormal() ? -$total : $total,
                ];
            })
            ->all();
    }

    /** Somme de toutes les écritures, débits comptés en négatif : elle doit valoir zéro. */
    private function imbalance(): int
    {
        return (int) LedgerEntry::selectRaw("coalesce(sum(case when direction = 'credit' then amount else -amount end), 0) as total")
            ->value('total');
    }
}
