<?php

namespace App\Models;

use App\Enums\JoinRequestStatus;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/** Demande d'adhésion à une organisation ou à une tontine ouverte aux demandes. */
class JoinRequest extends Model
{
    protected $fillable = [
        'organization_id', 'tontine_id', 'user_id', 'message', 'status', 'decision_reason', 'decided_by', 'decided_at',
    ];

    protected $attributes = ['status' => 'en_attente'];

    protected function casts(): array
    {
        return [
            'status' => JoinRequestStatus::class,
            'decided_at' => 'datetime',
        ];
    }

    public function organization(): BelongsTo
    {
        return $this->belongsTo(Organization::class);
    }

    public function tontine(): BelongsTo
    {
        return $this->belongsTo(Tontine::class);
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    /** @param  Builder<JoinRequest>  $query */
    public function scopePending(Builder $query): void
    {
        $query->where('status', JoinRequestStatus::Pending);
    }

    public function isPending(): bool
    {
        return $this->status === JoinRequestStatus::Pending;
    }
}
