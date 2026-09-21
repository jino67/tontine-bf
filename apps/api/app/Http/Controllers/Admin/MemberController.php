<?php

namespace App\Http\Controllers\Admin;

use App\Enums\AccountKind;
use App\Http\Controllers\Controller;
use App\Models\Account;
use App\Models\User;
use App\Models\WalletTransaction;
use App\Services\Wallet\WalletLimits;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\View\View;

/**
 * Comptes des membres : recherche, niveau de portefeuille, suspension.
 *
 * Suspendre un compte l'empêche de se connecter et de créer, mais ne touche ni à son solde
 * ni à son historique : l'argent d'un membre suspendu reste le sien.
 */
class MemberController extends Controller
{
    public function index(Request $request): View
    {
        $search = trim((string) $request->query('q'));

        $members = User::query()
            ->when($search !== '', fn ($query) => $query
                ->where('phone', 'like', '%'.$search.'%')
                ->orWhere('name', 'like', '%'.$search.'%')
                ->orWhere('email', 'like', '%'.$search.'%'))
            ->withCount('memberships')
            ->latest('id')
            ->limit(100)
            ->get();

        return view('admin.members', ['members' => $members, 'search' => $search]);
    }

    public function show(User $member): View
    {
        return view('admin.member', [
            'member' => $member,
            'limits' => WalletLimits::forUser($member),
            'balance' => Account::of($member)->balance(),
            'transactions' => WalletTransaction::where('user_id', $member->id)->latest('id')->limit(50)->get(),
            'organizations' => $member->organizations()->orderBy('name')->get(),
            'suspense' => Account::system(AccountKind::Suspense)->balance(),
        ]);
    }

    public function update(Request $request, User $member): RedirectResponse
    {
        $action = $request->validate([
            'action' => ['required', 'in:bloquer,debloquer,verifier,retirer_verification'],
            'reason' => ['nullable', 'string', 'max:200'],
        ]);

        match ($action['action']) {
            'bloquer' => $this->block($member, $action['reason'] ?? null),
            'debloquer' => $member->forceFill(['blocked_at' => null, 'blocked_reason' => null])->save(),
            'verifier' => $member->forceFill(['wallet_verified_at' => now()])->save(),
            'retirer_verification' => $member->forceFill(['wallet_verified_at' => null])->save(),
        };

        return back()->with('status', 'Compte mis à jour.');
    }

    /** Un compte suspendu perd ses jetons de connexion : la suspension prend effet tout de suite. */
    private function block(User $member, ?string $reason): void
    {
        $member->forceFill(['blocked_at' => now(), 'blocked_reason' => $reason])->save();
        $member->tokens()->delete();
    }
}
