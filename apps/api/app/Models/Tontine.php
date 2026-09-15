<?php

namespace App\Models;

use App\Enums\Frequency;
use App\Enums\TontineStatus;
use App\Enums\TontineType;
use App\Exceptions\DomainRuleException;
use Database\Factories\TontineFactory;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\HasManyThrough;
use Illuminate\Database\Eloquent\Relations\HasOne;

class Tontine extends Model
{
    /** @use HasFactory<TontineFactory> */
    use HasFactory;

    protected $fillable = [
        'organization_id', 'created_by', 'name', 'type', 'amount', 'frequency', 'starts_on',
        'cycles_count', 'max_members', 'goal', 'status', 'started_at',
    ];

    protected $attributes = ['status' => 'brouillon'];

    protected function casts(): array
    {
        return [
            'type' => TontineType::class,
            'frequency' => Frequency::class,
            'status' => TontineStatus::class,
            'amount' => 'integer',
            'cycles_count' => 'integer',
            'max_members' => 'integer',
            'starts_on' => 'immutable_date',
            'started_at' => 'datetime',
        ];
    }

    public function organization(): BelongsTo
    {
        return $this->belongsTo(Organization::class);
    }

    public function creator(): BelongsTo
    {
        return $this->belongsTo(User::class, 'created_by');
    }

    public function members(): HasMany
    {
        return $this->hasMany(TontineMember::class);
    }

    public function cycles(): HasMany
    {
        return $this->hasMany(Cycle::class);
    }

    public function draw(): HasOne
    {
        return $this->hasOne(Draw::class);
    }

    public function contributions(): HasManyThrough
    {
        return $this->hasManyThrough(Contribution::class, Cycle::class);
    }

    /** Nombre de membres, totaux dus et payés, prochaine échéance. */
    public function scopeWithProgress(Builder $query): void
    {
        $query->withCount('members')
            ->withSum('contributions as amount_due_total', 'amount_due')
            ->withSum('contributions as amount_paid_total', 'amount_paid')
            ->withMin(
                ['cycles as next_due_on' => fn ($cycles) => $cycles->where('due_on', '>=', today()->toDateString())],
                'due_on',
            );
    }

    /** Passe la tontine à « terminée » quand toutes les cotisations sont payées, et la rouvre sinon. */
    public function refreshCompletion(): void
    {
        if ($this->status !== TontineStatus::Active && $this->status !== TontineStatus::Completed) {
            return;
        }

        $unpaid = $this->contributions()
            ->whereColumn('contributions.amount_paid', '<', 'contributions.amount_due')
            ->exists();

        $status = $unpaid ? TontineStatus::Active : TontineStatus::Completed;

        if ($status !== $this->status) {
            $this->update(['status' => $status]);
        }
    }

    public function hasMember(int $userId): bool
    {
        return $this->members()->where('user_id', $userId)->exists();
    }

    public function addMember(User $user, int $shares = 1, ?int $position = null): TontineMember
    {
        if ($this->status !== TontineStatus::Draft) {
            throw new DomainRuleException('Les inscriptions à cette tontine sont closes.');
        }

        if ($this->hasMember($user->id)) {
            throw new DomainRuleException('Ce membre participe déjà à cette tontine.');
        }

        $limit = $this->type === TontineType::PersonalSavings ? 1 : $this->max_members;

        if ($limit !== null && $this->members()->count() >= $limit) {
            throw new DomainRuleException('Cette tontine est complète.');
        }

        return $this->members()->create([
            'organization_id' => $this->organization_id,
            'user_id' => $user->id,
            'shares' => $shares,
            'position' => $position,
        ]);
    }
}
