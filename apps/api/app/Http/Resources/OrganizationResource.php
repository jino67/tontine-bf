<?php

namespace App\Http\Resources;

use App\Enums\Role;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class OrganizationResource extends JsonResource
{
    private ?Role $role = null;

    public function withRole(?Role $role): static
    {
        $this->role = $role;

        return $this;
    }

    public function toArray(Request $request): array
    {
        $role = $this->role
            ?? ($this->pivot?->role ? Role::from($this->pivot->role) : null)
            ?? $request->attributes->get('membership')?->role;

        return [
            'id' => $this->id,
            'name' => $this->name,
            'slug' => $this->slug,
            'plan' => $this->plan,
            'currency' => $this->currency,
            'timezone' => $this->timezone,
            'role' => $role?->value,
            'visibility' => $this->visibility->value,
            'join_policy' => $this->join_policy->value,
            'share_url' => $this->resource->shareUrl(),
            'created_at' => $this->created_at?->toIso8601String(),
        ];
    }
}
