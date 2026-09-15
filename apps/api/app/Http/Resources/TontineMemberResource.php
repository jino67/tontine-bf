<?php

namespace App\Http\Resources;

use App\Http\Resources\Concerns\PresentsPhone;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class TontineMemberResource extends JsonResource
{
    use PresentsPhone;

    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'shares' => $this->shares,
            'position' => $this->position,
            'user' => $this->whenLoaded('user', fn () => [
                'id' => $this->user->id,
                'name' => $this->user->name,
                'phone' => $this->phoneFor($request, $this->user),
            ]),
        ];
    }
}
