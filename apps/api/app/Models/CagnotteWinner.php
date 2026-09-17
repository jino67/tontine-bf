<?php

namespace App\Models;

use App\Enums\PaymentMethod;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\MorphOne;

/** Gagnant d'une cagnotte à gagnants, tiré au sort. La colonne designated n'est plus utilisée. */
class CagnotteWinner extends Model
{
    protected $fillable = [
        'organization_id', 'cagnotte_id', 'rank', 'user_id', 'prize_amount',
        'paid_at', 'paid_method', 'paid_reference', 'paid_by', 'confirmed_at',
    ];

    protected function casts(): array
    {
        return [
            'rank' => 'integer',
            'user_id' => 'integer',
            'prize_amount' => 'integer',
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

    /** Dernière remise tentée par PayDunya. */
    public function latestPayout(): MorphOne
    {
        return $this->morphOne(Payout::class, 'payable')->latestOfMany();
    }
}
