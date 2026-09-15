<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class ContributionResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'cycle_id' => $this->cycle_id,
            'tontine_member_id' => $this->tontine_member_id,
            'member' => TontineMemberResource::make($this->whenLoaded('member')),
            'amount_due' => $this->amount_due,
            'amount_paid' => $this->amount_paid,
            'method' => $this->method?->value,
            'reference' => $this->reference,
            'paid_at' => $this->paid_at?->toIso8601String(),
            'status' => $this->resource->status()->value,
            'confirmed_at' => $this->confirmed_at?->toIso8601String(),
        ];
    }
}
