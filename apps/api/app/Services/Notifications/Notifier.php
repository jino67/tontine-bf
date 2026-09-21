<?php

namespace App\Services\Notifications;

use App\Enums\NotificationChannel;
use App\Enums\NotificationType;
use App\Models\Notification;
use App\Models\NotificationSetting;
use App\Models\User;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Carbon;

/**
 * Mise en file des messages.
 *
 * Quatre règles tenues ici, et nulle part ailleurs :
 * — rien à qui a coupé les relances, ou coupé cette tontine précise ;
 * — jamais deux fois le même message dans la même journée ;
 * — heures décentes, entre 7 h et 20 h à Ouagadougou, sauf pour l'argent et les tirages ;
 * — le canal descend jusqu'à ce qui est réellement branché, sans jamais rien perdre :
 *   au pire, le message reste visible dans l'application.
 */
class Notifier
{
    private const TIMEZONE = 'Africa/Ouagadougou';

    private const FROM_HOUR = 7;

    private const TO_HOUR = 20;

    /**
     * @param  array{related?: Model|null, organization_id?: int|null, dedupe?: string|null, payload?: array<string, mixed>}  $options
     */
    public function queue(User $user, NotificationType $type, string $title, string $body, array $options = []): ?Notification
    {
        $settings = NotificationSetting::forUser($user);
        $related = $options['related'] ?? null;

        if ($type->isReminder() && (! $settings->reminders || $settings->isMuted($related))) {
            return null;
        }

        $key = $options['dedupe'] ?? $this->dedupeKey($type, $related);
        $existing = Notification::where('user_id', $user->id)->where('dedupe_key', $key)->first();

        if ($existing !== null) {
            return $existing;
        }

        return Notification::create([
            'user_id' => $user->id,
            'organization_id' => $options['organization_id'] ?? null,
            'type' => $type,
            'channel' => $this->channelFor($user, $type, $settings),
            'title' => $title,
            'body' => $body,
            'related_type' => $related?->getMorphClass(),
            'related_id' => $related?->getKey(),
            'dedupe_key' => $key,
            'send_after' => $this->decentHour($type),
            'payload' => $options['payload'] ?? null,
        ]);
    }

    /** Un même message, un même jour, une seule fois. */
    private function dedupeKey(NotificationType $type, ?Model $related): string
    {
        $target = $related === null ? '' : NotificationSetting::key($related);

        return $type->value.'|'.$target.'|'.now()->timezone(self::TIMEZONE)->toDateString();
    }

    /**
     * Descend du canal visé vers ce qui est branché et accepté. Rien ne se perd :
     * tout message reste au minimum visible dans l'application.
     */
    private function channelFor(User $user, NotificationType $type, NotificationSetting $settings): NotificationChannel
    {
        $chain = match ($type->preferredChannel()) {
            NotificationChannel::Sms => [NotificationChannel::Sms, NotificationChannel::WhatsApp, NotificationChannel::Mail],
            NotificationChannel::WhatsApp => [NotificationChannel::WhatsApp, NotificationChannel::Mail],
            NotificationChannel::Mail => [NotificationChannel::Mail],
            NotificationChannel::Push => [NotificationChannel::Push],
            NotificationChannel::App => [],
        };

        foreach ($chain as $channel) {
            $reachable = $channel !== NotificationChannel::Mail || $user->email !== null;

            if ($channel->isAvailable() && $reachable && $settings->allows($channel)) {
                return $channel;
            }
        }

        return NotificationChannel::App;
    }

    /** Ce qui tombe la nuit attend le matin. L'argent et les tirages, eux, partent tout de suite. */
    private function decentHour(NotificationType $type): ?Carbon
    {
        if ($type->isImmediate()) {
            return null;
        }

        $local = now()->timezone(self::TIMEZONE);

        if ($local->hour >= self::FROM_HOUR && $local->hour < self::TO_HOUR) {
            return null;
        }

        $morning = $local->hour < self::FROM_HOUR
            ? $local->copy()->setTime(self::FROM_HOUR, 0)
            : $local->copy()->addDay()->setTime(self::FROM_HOUR, 0);

        return $morning->utc();
    }
}
