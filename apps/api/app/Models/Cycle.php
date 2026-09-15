<?php

namespace App\Models;

use App\Enums\CycleStatus;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Cycle extends Model
{
    protected $fillable = ['organization_id', 'tontine_id', 'number', 'due_on', 'beneficiary_member_id'];

    protected function casts(): array
    {
        return [
            'number' => 'integer',
            'due_on' => 'immutable_date',
            'beneficiary_member_id' => 'integer',
        ];
    }

    public function tontine(): BelongsTo
    {
        return $this->belongsTo(Tontine::class);
    }

    public function beneficiary(): BelongsTo
    {
        return $this->belongsTo(TontineMember::class, 'beneficiary_member_id');
    }

    public function contributions(): HasMany
    {
        return $this->hasMany(Contribution::class);
    }

    public function scopeWithContributionTotals(Builder $query): void
    {
        $query->withSum('contributions as amount_due_total', 'amount_due')
            ->withSum('contributions as amount_paid_total', 'amount_paid');
    }

    public function status(): CycleStatus
    {
        $due = (int) ($this->amount_due_total ?? $this->contributions()->sum('amount_due'));
        $paid = (int) ($this->amount_paid_total ?? $this->contributions()->sum('amount_paid'));

        if ($due > 0 && $paid >= $due) {
            return CycleStatus::Settled;
        }

        return $this->due_on->isFuture() ? CycleStatus::Upcoming : CycleStatus::Open;
    }
}
