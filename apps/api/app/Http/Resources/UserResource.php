<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** Profil de l'utilisateur connecté. */
class UserResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'phone' => $this->phone,
            'name' => $this->name,
            'email' => $this->email,
            'locale' => $this->locale,
            'phone_verified_at' => $this->phone_verified_at?->toIso8601String(),
        ];
    }
}
