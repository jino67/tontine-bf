<?php

namespace App\Models;

use App\Enums\AccountKind;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\MorphTo;

/**
 * Compte du grand livre.
 *
 * Son solde n'est jamais stocké : il se lit en additionnant ses écritures. Une colonne de solde
 * finirait tôt ou tard par diverger, et un écart de solde dans une tontine est impardonnable.
 */
class Account extends Model
{
    protected $fillable = ['code', 'kind', 'owner_type', 'owner_id', 'currency', 'label'];

    protected $attributes = ['currency' => 'XOF'];

    protected function casts(): array
    {
        return ['kind' => AccountKind::class];
    }

    public function entries(): HasMany
    {
        return $this->hasMany(LedgerEntry::class);
    }

    public function owner(): MorphTo
    {
        return $this->morphTo();
    }

    /** Compte d'un membre, d'une organisation ou d'une cagnotte, créé au premier besoin. */
    public static function of(Model $owner): self
    {
        $kind = match (true) {
            $owner instanceof User => AccountKind::Member,
            $owner instanceof Organization => AccountKind::Organization,
            $owner instanceof Cagnotte => AccountKind::Cagnotte,
            default => throw new \InvalidArgumentException('Ce type d’objet n’a pas de compte.'),
        };

        return static::firstOrCreate(
            ['code' => $kind->value.':'.$owner->getKey()],
            ['kind' => $kind, 'owner_type' => $owner->getMorphClass(), 'owner_id' => $owner->getKey()],
        );
    }

    /** Comptes de la plateforme : recettes, règlement PayDunya, compte d'attente. */
    public static function system(AccountKind $kind): self
    {
        return static::firstOrCreate(
            ['code' => $kind === AccountKind::Settlement ? 'reglement:paydunya' : $kind->value],
            ['kind' => $kind, 'label' => $kind->label()],
        );
    }

    public function balance(): int
    {
        $total = (int) $this->entries()
            ->selectRaw("coalesce(sum(case when direction = 'credit' then amount else -amount end), 0) as total")
            ->value('total');

        return $this->kind->isDebitNormal() ? -$total : $total;
    }
}
