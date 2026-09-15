<?php

namespace App\Models;

use App\Enums\PaymentStatus;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\MorphTo;

/** Paiement en ligne d'un membre, confirmé par PayDunya puis affecté une seule fois. */
class Payment extends Model
{
    protected $fillable = [
        'organization_id', 'user_id', 'payable_type', 'payable_id', 'amount', 'provider', 'token', 'checkout_url',
        'status', 'receipt_url', 'failure_reason', 'payload', 'paid_at', 'applied_at',
    ];

    protected $hidden = ['payload'];

    protected $attributes = ['status' => 'en_attente', 'provider' => 'paydunya'];

    protected function casts(): array
    {
        return [
            'user_id' => 'integer',
            'amount' => 'integer',
            'status' => PaymentStatus::class,
            'payload' => 'array',
            'paid_at' => 'datetime',
            'applied_at' => 'datetime',
        ];
    }

    public function payable(): MorphTo
    {
        return $this->morphTo();
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function organization(): BelongsTo
    {
        return $this->belongsTo(Organization::class);
    }
}
