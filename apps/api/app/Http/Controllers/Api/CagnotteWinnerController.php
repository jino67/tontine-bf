<?php

namespace App\Http\Controllers\Api;

use App\Enums\PaymentMethod;
use App\Enums\WalletOperation;
use App\Exceptions\DomainRuleException;
use App\Http\Controllers\Concerns\AuthorizesOrganizationRoles;
use App\Http\Controllers\Controller;
use App\Http\Resources\CagnotteResource;
use App\Models\Cagnotte;
use App\Models\CagnotteWinner;
use App\Models\Organization;
use App\Services\PayoutService;
use App\Services\Wallet\WalletService;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

/** Remise de chaque gain, manuelle ou par PayDunya, puis confirmée par le gagnant. */
class CagnotteWinnerController extends Controller
{
    use AuthorizesOrganizationRoles;

    public function __construct(private PayoutService $payouts, private WalletService $wallet) {}

    public function payout(Request $request, Organization $organization, Cagnotte $cagnotte, CagnotteWinner $winner): CagnotteResource
    {
        $this->ensureCanManage($request);

        if ($winner->paid_at !== null) {
            throw new DomainRuleException('La remise de ce gain est déjà enregistrée.');
        }

        PayoutService::ensureNoneInProgress($winner);

        $data = $request->validate([
            'method' => ['required', Rule::enum(PaymentMethod::class)],
            'reference' => ['nullable', 'string', 'max:100'],
            'withdraw_mode' => ['required_if:method,paydunya', 'nullable', Rule::in(PayoutService::WITHDRAW_MODES)],
            'phone' => ['required_if:method,paydunya', 'nullable', 'string', 'regex:/^[\d\s+]{8,16}$/'],
        ]);

        if ($data['method'] === PaymentMethod::PayDunya->value) {
            $this->payouts->send($winner, $organization->id, $request->user(), $winner->prize_amount, $data['phone'], $data['withdraw_mode'], $winner->user_id);
        } elseif ($data['method'] === PaymentMethod::Wallet->value) {
            // Le gain reste dans l'application : rien ne sort, donc rien n'est facturé.
            $this->wallet->creditFrom(
                $cagnotte,
                $winner->user,
                WalletOperation::Prize,
                $winner->prize_amount,
                related: $winner,
                description: "Gain de {$cagnotte->title}",
                organizationId: $organization->id,
            );

            $winner->update([
                'paid_at' => now(),
                'paid_method' => PaymentMethod::Wallet,
                'paid_by' => $request->user()->id,
                'confirmed_at' => now(),
            ]);
        } else {
            $winner->update([
                'paid_at' => now(),
                'paid_method' => $data['method'],
                'paid_reference' => $data['reference'] ?? null,
                'paid_by' => $request->user()->id,
            ]);
        }

        return $this->detail($organization, $cagnotte);
    }

    public function confirm(Request $request, Organization $organization, Cagnotte $cagnotte, CagnotteWinner $winner): CagnotteResource
    {
        abort_unless($winner->user_id === $request->user()->id, 403, 'Seul le gagnant peut confirmer la réception de son gain.');

        if ($winner->paid_at === null) {
            throw new DomainRuleException('Ce gain n’a pas encore été remis.');
        }

        if ($winner->confirmed_at === null) {
            $winner->update(['confirmed_at' => now()]);
        }

        return $this->detail($organization, $cagnotte);
    }

    private function detail(Organization $organization, Cagnotte $cagnotte): CagnotteResource
    {
        return CagnotteResource::make($organization->cagnottes()->whereKey($cagnotte->id)->withDetail()->firstOrFail());
    }
}
