<?php

namespace App\Models;

use App\Enums\LedgerDirection;
use App\Enums\WalletOperation;
use App\Enums\WalletStatus;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\MorphTo;

/** Lecture lisible d'un mouvement, telle qu'elle apparaît dans l'historique du membre. */
class WalletTransaction extends Model
{
    protected $fillable = [
        'reference', 'user_id', 'organization_id', 'type', 'status', 'direction', 'amount', 'fee_amount',
        'balance_after', 'counterparty_user_id', 'related_type', 'related_id', 'payment_id', 'payout_id',
        'description', 'failure_reason',
    ];

    protected $attributes = ['status' => 'reussie', 'fee_amount' => 0];

    protected function casts(): array
    {
        return [
            'type' => WalletOperation::class,
            'status' => WalletStatus::class,
            'direction' => LedgerDirection::class,
            'amount' => 'integer',
            'fee_amount' => 'integer',
            'balance_after' => 'integer',
        ];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function counterparty(): BelongsTo
    {
        return $this->belongsTo(User::class, 'counterparty_user_id');
    }

    public function related(): MorphTo
    {
        return $this->morphTo();
    }

    public function payout(): BelongsTo
    {
        return $this->belongsTo(Payout::class);
    }

    /** Ce que l'opération change sur le solde : négatif quand l'argent sort. */
    public function signedAmount(): int
    {
        return $this->direction === LedgerDirection::Credit ? $this->amount : -$this->amount;
    }
}
