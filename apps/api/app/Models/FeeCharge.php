<?php

namespace App\Models;

use App\Enums\FeeOperation;
use App\Enums\FeePayer;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\MorphTo;

/** Frais réellement prélevés sur une opération, avec la règle qui les a produits. */
class FeeCharge extends Model
{
    protected $fillable = [
        'organization_id', 'user_id', 'fee_rule_id', 'operation', 'chargeable_type', 'chargeable_id',
        'base_amount', 'fee_amount', 'rate_bp', 'fixed_amount', 'payer', 'provider_cost', 'platform_margin', 'note',
    ];

    protected function casts(): array
    {
        return [
            'operation' => FeeOperation::class,
            'payer' => FeePayer::class,
            'base_amount' => 'integer',
            'fee_amount' => 'integer',
            'rate_bp' => 'integer',
            'fixed_amount' => 'integer',
            'provider_cost' => 'integer',
            'platform_margin' => 'integer',
        ];
    }

    public function chargeable(): MorphTo
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
