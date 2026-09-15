<?php

namespace App\Http\Controllers\Api;

use App\Enums\CagnotteStatus;
use App\Enums\PaymentMethod;
use App\Exceptions\DomainRuleException;
use App\Http\Controllers\Concerns\AuthorizesOrganizationRoles;
use App\Http\Controllers\Controller;
use App\Http\Resources\CagnotteResource;
use App\Models\Cagnotte;
use App\Models\Organization;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

/** Remise des fonds au bénéficiaire, enregistrée par un responsable puis confirmée par le bénéficiaire. */
class CagnotteHandoverController extends Controller
{
    use AuthorizesOrganizationRoles;

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

        $data = $request->validate([
            'amount' => ['required', 'integer', 'min:1', 'max:'.max(1, $cagnotte->collectedAmount())],
            'method' => ['required', Rule::enum(PaymentMethod::class)],
            'reference' => ['nullable', 'string', 'max:100'],
        ]);

        $cagnotte->update([
            'status' => CagnotteStatus::HandedOver,
            'closed_at' => $cagnotte->closed_at ?? $cagnotte->ends_at,
            'handover_amount' => $data['amount'],
            'handover_method' => $data['method'],
            'handover_reference' => $data['reference'] ?? null,
            'handed_over_at' => now(),
            'handover_recorded_by' => $request->user()->id,
        ]);

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
