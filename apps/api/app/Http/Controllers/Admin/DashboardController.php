<?php

namespace App\Http\Controllers\Admin;

use App\Enums\AccountKind;
use App\Enums\CagnotteStatus;
use App\Enums\PaymentStatus;
use App\Enums\WalletStatus;
use App\Http\Controllers\Controller;
use App\Models\Account;
use App\Models\Cagnotte;
use App\Models\FeeCharge;
use App\Models\Organization;
use App\Models\Payment;
use App\Models\Report;
use App\Models\Tontine;
use App\Models\User;
use App\Models\WalletTransaction;
use Illuminate\View\View;

/** Les chiffres qui disent en un coup d'œil si la plateforme tourne. */
class DashboardController extends Controller
{
    public function __invoke(): View
    {
        $month = now()->startOfMonth();

        return view('admin.dashboard', [
            'counts' => [
                'membres' => User::count(),
                'organisations' => Organization::where('kind', 'standard')->count(),
                'tontines' => Tontine::count(),
                'cagnottes ouvertes' => Cagnotte::where('status', CagnotteStatus::Open)->where('ends_at', '>', now())->count(),
            ],
            'money' => [
                'encaissé ce mois' => (int) Payment::where('status', PaymentStatus::Paid)->where('paid_at', '>=', $month)->sum('amount'),
                'frais perçus ce mois' => (int) FeeCharge::where('created_at', '>=', $month)->sum('fee_amount'),
                'marge estimée ce mois' => (int) FeeCharge::where('created_at', '>=', $month)->sum('platform_margin'),
                'soldes des membres' => $this->memberBalances(),
            ],
            'alerts' => [
                'signalements à traiter' => Report::whereNull('reviewed_at')->count(),
                'retraits en attente' => WalletTransaction::where('type', 'retrait')->where('status', WalletStatus::Pending)->count(),
                'paiements reçus non affectés' => Payment::where('status', PaymentStatus::Paid)->whereNull('applied_at')->count(),
                'compte d’attente' => Account::system(AccountKind::Suspense)->balance(),
            ],
            'recentCharges' => FeeCharge::with('user')->latest('id')->limit(10)->get(),
        ]);
    }

    /** Ce que la plateforme doit à ses membres : la somme de tous les soldes. */
    private function memberBalances(): int
    {
        return (int) Account::where('kind', AccountKind::Member)
            ->join('ledger_entries', 'ledger_entries.account_id', '=', 'accounts.id')
            ->selectRaw("coalesce(sum(case when direction = 'credit' then amount else -amount end), 0) as total")
            ->value('total');
    }
}
