<?php

namespace App\Models;

use App\Enums\CagnotteDuration;
use App\Enums\CagnotteMode;
use App\Enums\CagnotteStatus;
use App\Enums\PaymentMethod;
use Database\Factories\CagnotteFactory;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\MorphOne;

/**
 * Collecte à durée limitée, en deux modes :
 * solidaire (remise des fonds à un bénéficiaire) ou à gagnants (tickets et tirage au sort vérifiable).
 */
class Cagnotte extends Model
{
    /** @use HasFactory<CagnotteFactory> */
    use HasFactory;

    protected $fillable = [
        'organization_id', 'created_by', 'mode', 'title', 'description', 'duration', 'target_amount', 'min_amount',
        'beneficiary_user_id', 'beneficiary_name', 'opens_at', 'ends_at', 'status', 'closed_at',
        'handover_amount', 'handover_method', 'handover_reference', 'handed_over_at', 'handover_recorded_by',
        'handover_confirmed_at', 'ticket_price', 'winners_count', 'prize_split', 'fee_percent', 'designations',
        'draw_seed', 'draw_seed_hash', 'draw_tickets', 'draw_reveal_after', 'drawn_at',
    ];

    protected $hidden = ['draw_seed'];

    protected $attributes = ['mode' => 'solidaire', 'status' => 'ouverte', 'min_amount' => 100, 'fee_percent' => 0];

    protected function casts(): array
    {
        return [
            'mode' => CagnotteMode::class,
            'duration' => CagnotteDuration::class,
            'status' => CagnotteStatus::class,
            'target_amount' => 'integer',
            'min_amount' => 'integer',
            'beneficiary_user_id' => 'integer',
            'handover_amount' => 'integer',
            'handover_method' => PaymentMethod::class,
            'ticket_price' => 'integer',
            'winners_count' => 'integer',
            'prize_split' => 'array',
            'fee_percent' => 'integer',
            'designations' => 'array',
            'draw_seed' => 'encrypted',
            'draw_tickets' => 'array',
            'opens_at' => 'datetime',
            'ends_at' => 'datetime',
            'closed_at' => 'datetime',
            'handed_over_at' => 'datetime',
            'handover_confirmed_at' => 'datetime',
            'draw_reveal_after' => 'datetime',
            'drawn_at' => 'datetime',
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

    public function beneficiary(): BelongsTo
    {
        return $this->belongsTo(User::class, 'beneficiary_user_id');
    }

    public function contributions(): HasMany
    {
        return $this->hasMany(CagnotteContribution::class);
    }

    public function winners(): HasMany
    {
        return $this->hasMany(CagnotteWinner::class);
    }

    /** Dernière remise des fonds tentée par PayDunya (cagnotte solidaire). */
    public function latestPayout(): MorphOne
    {
        return $this->morphOne(Payout::class, 'payable')->latestOfMany();
    }

    public function scopeWithTotals(Builder $query): void
    {
        $query->withSum('contributions as collected_amount', 'amount')
            ->withSum('contributions as tickets_total', 'tickets')
            ->withCount('contributions');
    }

    public function scopeWithDetail(Builder $query): void
    {
        $query->withTotals()->with([
            'beneficiary',
            'latestPayout',
            'contributions' => fn ($contributions) => $contributions->latest('paid_at')->latest('id'),
            'contributions.user',
            'winners' => fn ($winners) => $winners->orderBy('rank'),
            'winners.user',
            'winners.latestPayout',
        ]);
    }

    public function isPrize(): bool
    {
        return $this->mode === CagnotteMode::Prize;
    }

    /** Une cagnotte ouverte dont la date de fin est passée est considérée comme clôturée. */
    public function effectiveStatus(): CagnotteStatus
    {
        return $this->status === CagnotteStatus::Open && ! $this->ends_at->isFuture()
            ? CagnotteStatus::Closed
            : $this->status;
    }

    public function acceptsContributions(): bool
    {
        return $this->effectiveStatus() === CagnotteStatus::Open;
    }

    public function collectedAmount(): int
    {
        return (int) ($this->collected_amount ?? $this->contributions()->sum('amount'));
    }

    public function ticketsFor(int $amount): int
    {
        return $this->isPrize() && $this->ticket_price > 0 ? intdiv($amount, $this->ticket_price) : 0;
    }
}
