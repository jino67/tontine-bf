<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class TontineResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'organization_id' => $this->organization_id,
            'name' => $this->name,
            'type' => $this->type->value,
            'amount' => $this->amount,
            'frequency' => $this->frequency->value,
            'starts_on' => $this->starts_on->toDateString(),
            'cycles_count' => $this->cycles_count,
            'max_members' => $this->max_members,
            'goal' => $this->goal,
            'status' => $this->status->value,
            'started_at' => $this->started_at?->toIso8601String(),
            'members_count' => $this->whenCounted('members'),
            'amount_due_total' => $this->whenHas('amount_due_total', fn ($value) => (int) $value),
            'amount_paid_total' => $this->whenHas('amount_paid_total', fn ($value) => (int) $value),
            'next_due_on' => $this->whenHas('next_due_on', fn ($value) => $value ? substr((string) $value, 0, 10) : null),
            'members' => TontineMemberResource::collection($this->whenLoaded('members')),
            'created_at' => $this->created_at?->toIso8601String(),
        ];
    }
}
