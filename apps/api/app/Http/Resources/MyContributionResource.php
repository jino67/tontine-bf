<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;

/** Cotisation vue par le membre concerné, avec le contexte du cycle et de la tontine. */
class MyContributionResource extends ContributionResource
{
    public function toArray(Request $request): array
    {
        $cycle = $this->cycle;

        return [
            ...parent::toArray($request),
            'cycle_number' => $cycle->number,
            'due_on' => $cycle->due_on->toDateString(),
            'is_late' => $this->amount_paid < $this->amount_due && $cycle->due_on->lt(today()),
            'is_beneficiary' => $cycle->beneficiary_member_id === $this->tontine_member_id,
            'tontine' => [
                'id' => $cycle->tontine->id,
                'name' => $cycle->tontine->name,
                'type' => $cycle->tontine->type->value,
                'organization_id' => $cycle->tontine->organization_id,
            ],
        ];
    }
}
