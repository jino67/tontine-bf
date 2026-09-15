<?php

namespace App\Http\Resources;

use App\Http\Resources\Concerns\PresentsPhone;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class CagnotteContributionResource extends JsonResource
{
    use PresentsPhone;

    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'cagnotte_id' => $this->cagnotte_id,
            'user' => $this->whenLoaded('user', fn () => [
                'id' => $this->user->id,
                'name' => $this->user->name,
                'phone' => $this->phoneFor($request, $this->user),
            ]),
            'amount' => $this->amount,
            'tickets' => $this->tickets,
            'method' => $this->method?->value,
            'reference' => $this->reference,
            'paid_at' => $this->paid_at?->toIso8601String(),
            'status' => $this->resource->status()->value,
            'confirmed_at' => $this->confirmed_at?->toIso8601String(),
        ];
    }
}
