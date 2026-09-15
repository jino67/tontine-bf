<?php

namespace App\Models;

use App\Enums\PayoutStatus;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\MorphTo;

/** Remise d'argent envoyée par PayDunya vers un compte mobile money. */
class Payout extends Model
{
    protected $fillable = [
        'organization_id', 'payable_type', 'payable_id', 'user_id', 'phone', 'withdraw_mode', 'amount', 'disburse_id',
        'token', 'transaction_id', 'status', 'failure_reason', 'payload', 'initiated_by', 'completed_at',
    ];

    protected $hidden = ['payload'];

    protected $attributes = ['status' => 'en_cours'];

    protected function casts(): array
    {
        return [
            'user_id' => 'integer',
            'amount' => 'integer',
            'status' => PayoutStatus::class,
            'payload' => 'array',
            'initiated_by' => 'integer',
            'completed_at' => 'datetime',
        ];
    }

    public function payable(): MorphTo
    {
        return $this->morphTo();
    }

    public function organization(): BelongsTo
    {
        return $this->belongsTo(Organization::class);
    }
}
