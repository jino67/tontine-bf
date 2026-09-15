<?php

namespace App\Models;

use App\Enums\PaymentMethod;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/** Gagnant d'une cagnotte : tiré au sort ou attribué publiquement par le responsable (designated). */
class CagnotteWinner extends Model
{
    protected $fillable = [
        'organization_id', 'cagnotte_id', 'rank', 'user_id', 'prize_amount', 'designated',
        'paid_at', 'paid_method', 'paid_reference', 'paid_by', 'confirmed_at',
    ];

    protected function casts(): array
    {
        return [
            'rank' => 'integer',
            'user_id' => 'integer',
            'prize_amount' => 'integer',
            'designated' => 'boolean',
            'paid_at' => 'datetime',
            'paid_method' => PaymentMethod::class,
            'confirmed_at' => 'datetime',
        ];
    }

    public function cagnotte(): BelongsTo
    {
        return $this->belongsTo(Cagnotte::class);
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}
