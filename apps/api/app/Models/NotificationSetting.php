<?php

namespace App\Models;

use App\Enums\NotificationChannel;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * Ce qu'un membre accepte de recevoir.
 *
 * Chacun peut couper les relances d'une tontine précise sans couper les autres :
 * un rappel qu'on ne peut pas éteindre finit par être ignoré, puis par fâcher.
 */
class NotificationSetting extends Model
{
    protected $fillable = ['user_id', 'reminders', 'mail', 'push', 'whatsapp', 'sms', 'muted'];

    protected $attributes = [
        'reminders' => true,
        'mail' => true,
        'push' => true,
        'whatsapp' => true,
        'sms' => false,
    ];

    protected function casts(): array
    {
        return [
            'reminders' => 'boolean',
            'mail' => 'boolean',
            'push' => 'boolean',
            'whatsapp' => 'boolean',
            'sms' => 'boolean',
            'muted' => 'array',
        ];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public static function forUser(User $user): self
    {
        return static::firstOrCreate(['user_id' => $user->id]);
    }

    /** « tontine:12 » : plus aucune relance pour cette tontine. */
    public function isMuted(?Model $related): bool
    {
        if ($related === null) {
            return false;
        }

        return in_array(self::key($related), $this->muted ?? [], true);
    }

    public function allows(NotificationChannel $channel): bool
    {
        return match ($channel) {
            NotificationChannel::App => true,
            NotificationChannel::Mail => $this->mail,
            NotificationChannel::Push => $this->push,
            NotificationChannel::WhatsApp => $this->whatsapp,
            NotificationChannel::Sms => $this->sms,
        };
    }

    public static function key(Model $related): string
    {
        return strtolower(class_basename($related)).':'.$related->getKey();
    }
}
