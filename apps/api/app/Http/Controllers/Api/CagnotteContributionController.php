<?php

namespace App\Http\Controllers\Api;

use App\Enums\CagnotteStatus;
use App\Enums\PaymentMethod;
use App\Exceptions\DomainRuleException;
use App\Http\Controllers\Concerns\AuthorizesOrganizationRoles;
use App\Http\Controllers\Controller;
use App\Http\Resources\CagnotteContributionResource;
use App\Models\Cagnotte;
use App\Models\CagnotteContribution;
use App\Models\Organization;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class CagnotteContributionController extends Controller
{
    use AuthorizesOrganizationRoles;

    /** Le trésorier enregistre une participation reçue en espèces ou par mobile money. */
    public function store(Request $request, Organization $organization, Cagnotte $cagnotte): JsonResponse
    {
        $this->ensureCanRecord($request);

        if (! $cagnotte->acceptsContributions()) {
            throw new DomainRuleException('Cette cagnotte est clôturée, elle n’accepte plus de participation.');
        }

        $data = $request->validate([
            'user_id' => ['required', 'integer', Rule::exists('organization_user', 'user_id')->where('organization_id', $organization->id)],
            ...$this->paymentRules($cagnotte),
        ], [
            'user_id.exists' => "Cette personne n'est pas membre de l'organisation.",
        ]);

        $contribution = $cagnotte->contributions()->create([
            'organization_id' => $organization->id,
            'user_id' => $data['user_id'],
            'amount' => $data['amount'],
            'tickets' => $cagnotte->ticketsFor((int) $data['amount']),
            'method' => $data['method'],
            'reference' => $data['reference'] ?? null,
            'paid_at' => $data['paid_at'] ?? now(),
            'recorded_by' => $request->user()->id,
        ]);

        return CagnotteContributionResource::make($contribution->load('user'))->response()->setStatusCode(201);
    }

    public function update(Request $request, Organization $organization, Cagnotte $cagnotte, CagnotteContribution $contribution): CagnotteContributionResource
    {
        $this->ensureCanRecord($request);

        if ($contribution->confirmed_at !== null) {
            throw new DomainRuleException('Participation déjà confirmée, elle ne peut plus être modifiée.');
        }

        if ($cagnotte->status === CagnotteStatus::HandedOver || $cagnotte->draw_seed_hash !== null) {
            throw new DomainRuleException('La collecte est terminée, les participations ne peuvent plus être modifiées.');
        }

        $data = $request->validate($this->paymentRules($cagnotte));

        $contribution->update([
            'amount' => $data['amount'],
            'tickets' => $cagnotte->ticketsFor((int) $data['amount']),
            'method' => $data['method'],
            'reference' => $data['reference'] ?? null,
            'paid_at' => $data['paid_at'] ?? $contribution->paid_at,
            'recorded_by' => $request->user()->id,
        ]);

        return CagnotteContributionResource::make($contribution->load('user'));
    }

    /** La personne confirme avoir versé la somme : la participation est alors verrouillée. */
    public function confirm(Request $request, Organization $organization, Cagnotte $cagnotte, CagnotteContribution $contribution): CagnotteContributionResource
    {
        abort_unless(
            $contribution->user_id === $request->user()->id,
            403,
            'Seule la personne concernée peut confirmer sa participation.',
        );

        if ($contribution->confirmed_at === null) {
            $contribution->update(['confirmed_at' => now()]);
        }

        return CagnotteContributionResource::make($contribution->load('user'));
    }

    private function paymentRules(Cagnotte $cagnotte): array
    {
        return [
            'amount' => ['required', 'integer', 'min:'.$cagnotte->min_amount, 'max:100000000'],
            'method' => ['required', Rule::enum(PaymentMethod::class)->except(PaymentMethod::PayDunya)],
            'reference' => ['nullable', 'string', 'max:100'],
            'paid_at' => ['nullable', 'date', 'before_or_equal:now'],
        ];
    }
}
