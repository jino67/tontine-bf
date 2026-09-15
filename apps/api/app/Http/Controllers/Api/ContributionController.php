<?php

namespace App\Http\Controllers\Api;

use App\Enums\PaymentMethod;
use App\Exceptions\DomainRuleException;
use App\Http\Controllers\Concerns\AuthorizesOrganizationRoles;
use App\Http\Controllers\Controller;
use App\Http\Resources\ContributionResource;
use App\Models\Contribution;
use App\Models\Cycle;
use App\Models\Organization;
use App\Models\Tontine;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class ContributionController extends Controller
{
    use AuthorizesOrganizationRoles;

    /** Le trésorier enregistre le montant reçu (espèces ou mobile money hors application). */
    public function update(Request $request, Organization $organization, Tontine $tontine, Cycle $cycle, Contribution $contribution): ContributionResource
    {
        $this->ensureCanRecord($request);

        if ($contribution->confirmed_at !== null) {
            throw new DomainRuleException('Cotisation déjà confirmée par le membre, elle ne peut plus être modifiée.');
        }

        $data = $request->validate([
            'amount_paid' => ['required', 'integer', 'min:0', 'max:'.$contribution->amount_due],
            'method' => ['required_unless:amount_paid,0', 'nullable', Rule::enum(PaymentMethod::class)],
            'reference' => ['nullable', 'string', 'max:100'],
            'paid_at' => ['nullable', 'date', 'before_or_equal:now'],
        ]);

        $paid = $data['amount_paid'] > 0;

        $contribution->update([
            'amount_paid' => $data['amount_paid'],
            'method' => $paid ? $data['method'] : null,
            'reference' => $paid ? ($data['reference'] ?? null) : null,
            'paid_at' => $paid ? ($data['paid_at'] ?? now()) : null,
            'recorded_by' => $paid ? $request->user()->id : null,
        ]);

        $tontine->refreshCompletion();

        return ContributionResource::make($contribution->load('member.user'));
    }

    /** Le membre confirme avoir bien versé la somme : la cotisation est alors verrouillée. */
    public function confirm(Request $request, Organization $organization, Tontine $tontine, Cycle $cycle, Contribution $contribution): ContributionResource
    {
        abort_unless(
            $contribution->member->user_id === $request->user()->id,
            403,
            'Seul le membre concerné peut confirmer sa cotisation.',
        );

        if ($contribution->amount_paid === 0) {
            throw new DomainRuleException('Aucun paiement enregistré à confirmer.');
        }

        if ($contribution->confirmed_at === null) {
            $contribution->update(['confirmed_at' => now()]);
        }

        return ContributionResource::make($contribution->load('member.user'));
    }
}
