<?php

namespace App\Http\Controllers\Api;

use App\Enums\CagnotteStatus;
use App\Enums\PaymentMethod;
use App\Enums\WalletOperation;
use App\Exceptions\DomainRuleException;
use App\Http\Controllers\Concerns\AuthorizesOrganizationRoles;
use App\Http\Controllers\Controller;
use App\Http\Resources\CagnotteResource;
use App\Models\Cagnotte;
use App\Models\Organization;
use App\Services\CagnotteCycles;
use App\Services\Fees\CagnotteFees;
use App\Services\PayoutService;
use App\Services\Wallet\WalletService;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

/** Remise des fonds au bénéficiaire, manuelle ou par PayDunya, puis confirmée par le bénéficiaire. */
class CagnotteHandoverController extends Controller
{
    use AuthorizesOrganizationRoles;

    public function __construct(
        private PayoutService $payouts,
        private CagnotteFees $fees,
        private WalletService $wallet,
        private CagnotteCycles $cycles,
    ) {}

    public function store(Request $request, Organization $organization, Cagnotte $cagnotte): CagnotteResource
    {
        $this->ensureCanManage($request);

        if ($cagnotte->isPrize()) {
            throw new DomainRuleException('Pour une cagnotte à gagnants, enregistrez la remise de chaque gain.');
        }

        if ($cagnotte->status === CagnotteStatus::HandedOver) {
            throw new DomainRuleException('La remise des fonds a déjà été enregistrée.');
        }

        if ($cagnotte->effectiveStatus() !== CagnotteStatus::Closed) {
            throw new DomainRuleException('Clôturez la cagnotte avant d’enregistrer la remise des fonds.');
        }

        PayoutService::ensureNoneInProgress($cagnotte);

        $data = $request->validate([
            // Le maximum remis est le pot : la part de la plateforme en est déjà retirée.
            'amount' => ['required', 'integer', 'min:1', 'max:'.max(1, $cagnotte->pot())],
            'method' => ['required', Rule::enum(PaymentMethod::class)],
            'reference' => ['nullable', 'string', 'max:100'],
            'withdraw_mode' => ['required_if:method,paydunya', 'nullable', Rule::in(PayoutService::WITHDRAW_MODES)],
            'phone' => ['required_if:method,paydunya', 'nullable', 'string', 'regex:/^[\d\s+]{8,16}$/'],
        ]);

        if ($data['method'] === PaymentMethod::PayDunya->value) {
            $this->payouts->send($cagnotte, $organization->id, $request->user(), (int) $data['amount'], $data['phone'], $data['withdraw_mode'], $cagnotte->beneficiary_user_id);
        } elseif ($data['method'] === PaymentMethod::Wallet->value) {
            if ($cagnotte->beneficiary === null) {
                throw new DomainRuleException('Le bénéficiaire de cette cagnotte n’est pas un membre : versez les fonds autrement.');
            }

            $this->wallet->creditFrom(
                $cagnotte,
                $cagnotte->beneficiary,
                WalletOperation::Handover,
                (int) $data['amount'],
                related: $cagnotte,
                description: "Fonds de {$cagnotte->title}",
                organizationId: $organization->id,
            );

            $cagnotte->update([
                'status' => CagnotteStatus::HandedOver,
                'closed_at' => $cagnotte->closed_at ?? $cagnotte->ends_at,
                'handover_amount' => $data['amount'],
                'handover_method' => PaymentMethod::Wallet,
                'handed_over_at' => now(),
                'handover_recorded_by' => $request->user()->id,
                'handover_confirmed_at' => now(),
            ]);
        } else {
            $cagnotte->update([
                'status' => CagnotteStatus::HandedOver,
                'closed_at' => $cagnotte->closed_at ?? $cagnotte->ends_at,
                'handover_amount' => $data['amount'],
                'handover_method' => $data['method'],
                'handover_reference' => $data['reference'] ?? null,
                'handed_over_at' => now(),
                'handover_recorded_by' => $request->user()->id,
            ]);
        }

        $this->fees->chargePlatform($cagnotte, 'Part de la plateforme retenue à la remise des fonds.');
        $this->cycles->relaunch($cagnotte);

        return CagnotteResource::make($organization->cagnottes()->whereKey($cagnotte->id)->withDetail()->firstOrFail());
    }

    public function confirm(Request $request, Organization $organization, Cagnotte $cagnotte): CagnotteResource
    {
        abort_unless(
            $cagnotte->beneficiary_user_id === $request->user()->id,
            403,
            'Seul le bénéficiaire peut confirmer la réception des fonds.',
        );

        if ($cagnotte->status !== CagnotteStatus::HandedOver) {
            throw new DomainRuleException('Aucune remise de fonds à confirmer.');
        }

        if ($cagnotte->handover_confirmed_at === null) {
            $cagnotte->update(['handover_confirmed_at' => now()]);
        }

        return CagnotteResource::make($organization->cagnottes()->whereKey($cagnotte->id)->withDetail()->firstOrFail());
    }
}
