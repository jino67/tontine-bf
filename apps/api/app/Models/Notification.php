<?php

namespace App\Models;

use App\Enums\NotificationChannel;
use App\Enums\NotificationType;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\MorphTo;

/** Message adressé à un membre, en attente d'envoi puis conservé comme trace. */
class Notification extends Model
{
    public const PENDING = 'en_attente';

    public const SENT = 'envoyee';

    public const FAILED = 'echouee';

    protected $fillable = [
        'user_id', 'organization_id', 'type', 'channel', 'status', 'title', 'body',
        'related_type', 'related_id', 'dedupe_key', 'send_after', 'sent_at', 'read_at',
        'failure_reason', 'payload',
    ];

    protected $attributes = ['status' => self::PENDING, 'channel' => 'application'];

    protected function casts(): array
    {
        return [
            'type' => NotificationType::class,
            'channel' => NotificationChannel::class,
            'payload' => 'array',
            'send_after' => 'datetime',
            'sent_at' => 'datetime',
            'read_at' => 'datetime',
        ];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function related(): MorphTo
    {
        return $this->morphTo();
    }

    /** Messages dont l'heure est venue. */
    public function scopeDue(Builder $query): void
    {
        $query->where('status', self::PENDING)
            ->where(fn (Builder $when) => $when->whereNull('send_after')->orWhere('send_after', '<=', now()))
            ->orderBy('id');
    }
}
