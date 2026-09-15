<?php

namespace App\Http\Controllers\Api;

use App\Enums\PaymentMethod;
use App\Exceptions\DomainRuleException;
use App\Http\Controllers\Concerns\AuthorizesOrganizationRoles;
use App\Http\Controllers\Controller;
use App\Http\Resources\CagnotteResource;
use App\Models\Cagnotte;
use App\Models\CagnotteWinner;
use App\Models\Organization;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

/** Remise de chaque gain, enregistrée par un responsable puis confirmée par le gagnant. */
class CagnotteWinnerController extends Controller
{
    use AuthorizesOrganizationRoles;

    public function payout(Request $request, Organization $organization, Cagnotte $cagnotte, CagnotteWinner $winner): CagnotteResource
    {
        $this->ensureCanManage($request);

        if ($winner->paid_at !== null) {
            throw new DomainRuleException('La remise de ce gain est déjà enregistrée.');
        }

        $data = $request->validate([
            'method' => ['required', Rule::enum(PaymentMethod::class)],
            'reference' => ['nullable', 'string', 'max:100'],
        ]);

        $winner->update([
            'paid_at' => now(),
            'paid_method' => $data['method'],
            'paid_reference' => $data['reference'] ?? null,
            'paid_by' => $request->user()->id,
        ]);

        return CagnotteResource::make($organization->cagnottes()->whereKey($cagnotte->id)->withDetail()->firstOrFail());
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

        return CagnotteResource::make($organization->cagnottes()->whereKey($cagnotte->id)->withDetail()->firstOrFail());
    }
}
