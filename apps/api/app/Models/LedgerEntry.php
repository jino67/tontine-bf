<?php

namespace App\Models;

use App\Enums\LedgerDirection;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\MorphTo;

/**
 * Écriture du grand livre. Immuable : une erreur se corrige par une écriture inverse,
 * jamais par une modification ni une suppression.
 */
class LedgerEntry extends Model
{
    public const UPDATED_AT = null;

    protected $fillable = [
        'transaction_ref', 'account_id', 'direction', 'amount', 'reference_type', 'reference_id', 'memo',
    ];

    protected function casts(): array
    {
        return [
            'direction' => LedgerDirection::class,
            'amount' => 'integer',
        ];
    }

    public function account(): BelongsTo
    {
        return $this->belongsTo(Account::class);
    }

    public function reference(): MorphTo
    {
        return $this->morphTo();
    }

    /** Effet de l'écriture sur le solde lisible du compte. */
    public function signedAmount(): int
    {
        $signed = $this->direction === LedgerDirection::Credit ? $this->amount : -$this->amount;

        return $this->account->kind->isDebitNormal() ? -$signed : $signed;
    }
}
