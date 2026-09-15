<?php

namespace App\Http\Resources;

use App\Http\Resources\Concerns\PresentsPhone;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class MembershipResource extends JsonResource
{
    use PresentsPhone;

    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'role' => $this->role->value,
            'user' => [
                'id' => $this->user->id,
                'name' => $this->user->name,
                'phone' => $this->phoneFor($request, $this->user),
            ],
            'joined_at' => $this->created_at?->toIso8601String(),
        ];
    }
}
