<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class DrawResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        $revealed = $this->resource->isRevealed();

        return [
            'id' => $this->id,
            'tontine_id' => $this->tontine_id,
            'status' => $revealed ? 'revele' : 'engage',
            'seed_hash' => $this->seed_hash,
            'slots' => $this->slots,
            // Visibles par tous les membres dès l'engagement, avant la révélation.
            'designations' => $this->designations ?? [],
            'reveal_after' => $this->reveal_after->toIso8601String(),
            'revealed_at' => $this->revealed_at?->toIso8601String(),
            'seed' => $this->when($revealed, fn () => $this->seed),
            'order' => $this->when($revealed, fn () => $this->result),
            'verification' => 'sha256(seed) doit être égal à seed_hash. Les parts tirées (slots) sont triées par '
                .'sha256(seed + "|" + part) dans l\'ordre croissant, puis placées dans les tours qui ne figurent pas '
                .'dans designations, du premier au dernier. Une part "12#1" désigne le membre 12.',
        ];
    }
}
