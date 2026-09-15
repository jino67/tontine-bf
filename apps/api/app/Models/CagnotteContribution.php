<?php

namespace App\Models;

use App\Enums\ContributionStatus;
use App\Enums\PaymentMethod;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/** Participation libre à une cagnotte, enregistrée par le trésorier puis confirmée par la personne. */
class CagnotteContribution extends Model
{
    protected $fillable = [
        'organization_id', 'cagnotte_id', 'user_id', 'amount', 'tickets', 'method', 'reference', 'paid_at',
        'recorded_by', 'confirmed_at',
    ];

    protected function casts(): array
    {
        return [
            'user_id' => 'integer',
            'amount' => 'integer',
            'tickets' => 'integer',
            'method' => PaymentMethod::class,
            'paid_at' => 'datetime',
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

    public function recorder(): BelongsTo
    {
        return $this->belongsTo(User::class, 'recorded_by');
    }

    public function status(): ContributionStatus
    {
        return $this->confirmed_at !== null ? ContributionStatus::Confirmed : ContributionStatus::Recorded;
    }
}
