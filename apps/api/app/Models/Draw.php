<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * Tirage de l'ordre de passage d'une tontine « tirage_ordre ».
 * Les tours attribués par le responsable (designations) sont publiés dès l'engagement, les autres sont tirés au sort.
 */
class Draw extends Model
{
    protected $fillable = [
        'organization_id', 'tontine_id', 'created_by', 'seed', 'seed_hash', 'slots', 'designations', 'result',
        'reveal_after', 'revealed_at',
    ];

    protected $hidden = ['seed'];

    protected function casts(): array
    {
        return [
            'seed' => 'encrypted',
            'slots' => 'array',
            'designations' => 'array',
            'result' => 'array',
            'reveal_after' => 'datetime',
            'revealed_at' => 'datetime',
        ];
    }

    public function tontine(): BelongsTo
    {
        return $this->belongsTo(Tontine::class);
    }

    public function isRevealed(): bool
    {
        return $this->revealed_at !== null;
    }
}
