<?php

namespace App\Models;

use App\Enums\CagnotteDuration;
use App\Enums\CagnotteMode;
use App\Enums\Visibility;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

/**
 * Modèle de cagnotte préparé depuis le back-office.
 *
 * Il sert à proposer des formules toutes prêtes — « Flash du vendredi », « Tombola du mois » —
 * pour qu'un responsable n'ait pas à décider du prix du ticket, du nombre de gagnants et de la
 * répartition à chaque fois. Rien n'y oblige : une cagnotte se crée toujours sans modèle.
 */
class CagnotteTemplate extends Model
{
    protected $fillable = [
        'name', 'description', 'mode', 'duration', 'custom_days', 'ticket_price', 'winners_count',
        'prize_split', 'min_amount', 'target_amount', 'fee_percent', 'recurring', 'visibility',
        'active', 'sort_order', 'created_by',
    ];

    protected $attributes = [
        'mode' => 'gagnants',
        'duration' => 'hebdo_7j',
        'min_amount' => 100,
        'fee_percent' => 0,
        'recurring' => false,
        'visibility' => 'publique',
        'active' => true,
        'sort_order' => 0,
    ];

    protected function casts(): array
    {
        return [
            'mode' => CagnotteMode::class,
            'duration' => CagnotteDuration::class,
            'visibility' => Visibility::class,
            'prize_split' => 'array',
            'custom_days' => 'integer',
            'ticket_price' => 'integer',
            'winners_count' => 'integer',
            'min_amount' => 'integer',
            'target_amount' => 'integer',
            'fee_percent' => 'integer',
            'recurring' => 'boolean',
            'active' => 'boolean',
            'sort_order' => 'integer',
        ];
    }

    public function cagnottes(): HasMany
    {
        return $this->hasMany(Cagnotte::class, 'template_id');
    }

    public function scopeUsable(Builder $query): void
    {
        $query->where('active', true)->orderBy('sort_order')->orderBy('name');
    }

    /**
     * Valeurs à reprendre à la création d'une cagnotte.
     *
     * @return array<string, mixed>
     */
    public function attributesForCagnotte(): array
    {
        return array_filter([
            'mode' => $this->mode,
            'duration' => $this->duration,
            'ticket_price' => $this->ticket_price,
            'winners_count' => $this->winners_count,
            'prize_split' => $this->prize_split,
            'min_amount' => $this->min_amount,
            'target_amount' => $this->target_amount,
            'fee_percent' => $this->fee_percent,
            'recurring' => $this->recurring,
            'visibility' => $this->visibility,
        ], fn ($value) => $value !== null);
    }
}
