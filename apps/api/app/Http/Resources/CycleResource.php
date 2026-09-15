<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class CycleResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'number' => $this->number,
            'due_on' => $this->due_on->toDateString(),
            'status' => $this->resource->status()->value,
            'beneficiary' => $this->whenLoaded(
                'beneficiary',
                fn () => $this->beneficiary ? TontineMemberResource::make($this->beneficiary) : null,
            ),
            'amount_due_total' => (int) $this->amount_due_total,
            'amount_paid_total' => (int) $this->amount_paid_total,
            'contributions' => ContributionResource::collection($this->whenLoaded('contributions')),
        ];
    }
}
