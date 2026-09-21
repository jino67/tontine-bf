<?php

namespace App\Models;

use App\Enums\CagnotteDuration;
use App\Enums\CagnotteMode;
use App\Enums\CagnotteStatus;
use App\Enums\PaymentMethod;
use App\Enums\Visibility;
use App\Models\Concerns\HasShareCode;
use App\Services\CagnottePrizeDraw;
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

    use HasShareCode;

    /** Lettre du chemin public : https://exemple.bf/c/ABCD2345 */
    public const SHARE_PATH = 'c';

    protected $fillable = [
        'organization_id', 'created_by', 'mode', 'title', 'description', 'duration', 'target_amount', 'min_amount',
        'beneficiary_user_id', 'beneficiary_name', 'opens_at', 'ends_at', 'status', 'closed_at',
        'handover_amount', 'handover_method', 'handover_reference', 'handed_over_at', 'handover_recorded_by',
        'handover_confirmed_at', 'ticket_price', 'winners_count', 'prize_split', 'fee_percent', 'platform_fee_bp',
        'draw_seed', 'draw_seed_hash', 'draw_tickets', 'draw_reveal_after', 'drawn_at', 'visibility',
        'recurring', 'series_id', 'edition', 'template_id',
    ];

    protected $hidden = ['draw_seed'];

    // Une cagnotte est visible de tous par défaut : c'est la demande, et le tirage vérifiable
    // vaut d'autant plus qu'il y a de témoins. Un responsable peut toujours la refermer.
    protected $attributes = ['mode' => 'solidaire', 'status' => 'ouverte', 'min_amount' => 100, 'fee_percent' => 0, 'visibility' => 'publique'];

    protected function casts(): array
    {
        return [
            'mode' => CagnotteMode::class,
            'visibility' => Visibility::class,
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
            'platform_fee_bp' => 'integer',
            'recurring' => 'boolean',
            'edition' => 'integer',
            'draw_seed' => 'encrypted',
            'draw_tickets' => 'array',
            'opens_at' => 'datetime',
            'ends_at' => 'datetime',
            'closed_at' => 'datetime',
            'handed_over_at' => 'datetime',
            'handover_confirmed_at' => 'datetime',
            'draw_reveal_after' => 'datetime',
            'drawn_at' => 'datetime',
            'hidden_at' => 'datetime',
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

    public function template(): BelongsTo
    {
        return $this->belongsTo(CagnotteTemplate::class, 'template_id');
    }

    /** Toutes les éditions de la série, la première comprise. */
    public function editions(): HasMany
    {
        return $this->hasMany(Cagnotte::class, 'series_id', 'id');
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
            ->withSum([
                'contributions as online_collected' => fn ($contributions) => $contributions
                    ->whereIn('method', [PaymentMethod::PayDunya->value, PaymentMethod::Wallet->value]),
            ], 'amount')
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

    /** Identifiant de la série : la première édition la porte elle-même. */
    public function seriesId(): int
    {
        return (int) ($this->series_id ?? $this->id);
    }

    /**
     * Édition en cours de la série. Un lien partagé reste collé à la première édition :
     * il doit toujours mener à celle qui est ouverte aujourd'hui.
     */
    public function currentEdition(): self
    {
        if (! $this->recurring) {
            return $this;
        }

        return static::where(fn ($query) => $query->where('series_id', $this->seriesId())->orWhere('id', $this->seriesId()))
            ->orderByDesc('edition')
            ->orderByDesc('id')
            ->first() ?? $this;
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

    /** Somme entrée par l'application : la seule base des frais de service. */
    public function onlineCollected(): int
    {
        return (int) ($this->online_collected ?? $this->contributions()
            ->whereIn('method', [PaymentMethod::PayDunya->value, PaymentMethod::Wallet->value])
            ->sum('amount'));
    }

    /**
     * Part de la plateforme. Le taux est figé à la création de la cagnotte : le pot reste
     * ainsi recalculable à l'identique par l'application, des mois plus tard.
     */
    public function platformFee(): int
    {
        return CagnottePrizeDraw::platformFee($this->onlineCollected(), (int) $this->platform_fee_bp);
    }

    /** Ce qui est partagé entre les gagnants, ou remis au bénéficiaire. */
    public function pot(): int
    {
        return CagnottePrizeDraw::pot($this->collectedAmount(), (int) $this->fee_percent, $this->platformFee());
    }

    public function ticketsFor(int $amount): int
    {
        return $this->isPrize() && $this->ticket_price > 0 ? intdiv($amount, $this->ticket_price) : 0;
    }
}
