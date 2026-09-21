<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class InvitationResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'code' => $this->code,
            'url' => rtrim((string) config('app.url'), '/').'/i/'.$this->code,
            'organization_id' => $this->organization_id,
            'tontine_id' => $this->tontine_id,
            'max_uses' => $this->max_uses,
            'used_count' => $this->used_count,
            'expires_at' => $this->expires_at?->toIso8601String(),
            'created_at' => $this->created_at?->toIso8601String(),
        ];
    }
}
