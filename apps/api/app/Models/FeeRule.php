<?php

namespace App\Models;

use App\Enums\FeeOperation;
use App\Enums\FeePayer;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * Règle de frais en vigueur pour une opération.
 *
 * Une règle ne se modifie pas : on la clôt en renseignant `ends_at`, et on en crée une nouvelle.
 * C'est ce qui permet d'expliquer, des mois plus tard, un montant facturé.
 */
class FeeRule extends Model
{
    protected $fillable = [
        'operation', 'organization_id', 'label', 'rate_bp', 'fixed_amount', 'min_amount', 'max_amount',
        'payer', 'starts_at', 'ends_at', 'active', 'created_by',
    ];

    protected $attributes = ['rate_bp' => 0, 'fixed_amount' => 0, 'min_amount' => 0, 'payer' => 'payeur', 'active' => true];

    protected function casts(): array
    {
        return [
            'operation' => FeeOperation::class,
            'payer' => FeePayer::class,
            'rate_bp' => 'integer',
            'fixed_amount' => 'integer',
            'min_amount' => 'integer',
            'max_amount' => 'integer',
            'active' => 'boolean',
            'starts_at' => 'datetime',
            'ends_at' => 'datetime',
        ];
    }

    public function organization(): BelongsTo
    {
        return $this->belongsTo(Organization::class);
    }

    /** Règles applicables aujourd'hui, la règle de l'organisation avant la règle générale. */
    public function scopeInForce(Builder $query, FeeOperation $operation, ?int $organizationId): void
    {
        $query->where('operation', $operation)
            ->where('active', true)
            ->where(fn (Builder $scope) => $scope->whereNull('organization_id')->when(
                $organizationId !== null,
                fn (Builder $inner) => $inner->orWhere('organization_id', $organizationId),
            ))
            ->where(fn (Builder $from) => $from->whereNull('starts_at')->orWhere('starts_at', '<=', now()))
            ->where(fn (Builder $to) => $to->whereNull('ends_at')->orWhere('ends_at', '>', now()))
            ->orderByRaw('organization_id is null')
            ->orderByDesc('starts_at')
            ->orderByDesc('id');
    }

    /** « 3,25 % » ou « 3,25 % + 100 FCFA ». */
    public function rateLabel(): string
    {
        $parts = [];

        if ($this->rate_bp > 0) {
            $parts[] = rtrim(rtrim(number_format($this->rate_bp / 100, 2, ',', ' '), '0'), ',').' %';
        }

        if ($this->fixed_amount > 0) {
            $parts[] = number_format($this->fixed_amount, 0, ',', ' ').' FCFA';
        }

        return $parts === [] ? 'gratuit' : implode(' + ', $parts);
    }
}
