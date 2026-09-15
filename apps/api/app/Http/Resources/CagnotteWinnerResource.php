<?php

namespace App\Http\Resources;

use App\Http\Resources\Concerns\PresentsPhone;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class CagnotteWinnerResource extends JsonResource
{
    use PresentsPhone;

    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'rank' => $this->rank,
            'user' => $this->whenLoaded('user', fn () => [
                'id' => $this->user->id,
                'name' => $this->user->name,
                'phone' => $this->phoneFor($request, $this->user),
            ]),
            'prize_amount' => $this->prize_amount,
            'designated' => $this->designated,
            'paid_at' => $this->paid_at?->toIso8601String(),
            'paid_method' => $this->paid_method?->value,
            'paid_reference' => $this->paid_reference,
            'confirmed_at' => $this->confirmed_at?->toIso8601String(),
        ];
    }
}
