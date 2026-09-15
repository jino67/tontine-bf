<?php

namespace App\Models;

use App\Enums\ContributionStatus;
use App\Enums\PaymentMethod;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/** Cotisation due par un membre pour un cycle. Verrouillée une fois confirmée par le membre. */
class Contribution extends Model
{
    protected $fillable = [
        'organization_id', 'cycle_id', 'tontine_member_id', 'amount_due', 'amount_paid',
        'method', 'reference', 'paid_at', 'recorded_by', 'confirmed_at',
    ];

    protected $attributes = ['amount_paid' => 0];

    protected function casts(): array
    {
        return [
            'cycle_id' => 'integer',
            'tontine_member_id' => 'integer',
            'amount_due' => 'integer',
            'amount_paid' => 'integer',
            'method' => PaymentMethod::class,
            'paid_at' => 'datetime',
            'confirmed_at' => 'datetime',
        ];
    }

    public function cycle(): BelongsTo
    {
        return $this->belongsTo(Cycle::class);
    }

    public function member(): BelongsTo
    {
        return $this->belongsTo(TontineMember::class, 'tontine_member_id');
    }

    public function recorder(): BelongsTo
    {
        return $this->belongsTo(User::class, 'recorded_by');
    }

    public function status(): ContributionStatus
    {
        if ($this->confirmed_at !== null) {
            return ContributionStatus::Confirmed;
        }

        return $this->amount_paid > 0 ? ContributionStatus::Recorded : ContributionStatus::Pending;
    }
}
