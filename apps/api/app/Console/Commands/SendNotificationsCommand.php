<?php

namespace App\Console\Commands;

use App\Enums\NotificationChannel;
use App\Mail\NotificationDigestMail;
use App\Models\Notification;
use Illuminate\Console\Command;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Mail;

/**
 * Envoie les messages dont l'heure est venue.
 *
 * Regroupés par personne : un membre de trois tontines reçoit un e-mail le matin, pas trois.
 * Les messages destinés aux canaux pas encore branchés — push, WhatsApp, SMS — ne sont pas
 * perdus : ils restent visibles dans l'application, et la trace dit par où ils sont passés.
 */
class SendNotificationsCommand extends Command
{
    protected $signature = 'notifications:send {--limit=200 : nombre maximum de messages traités}';

    protected $description = 'Envoie les notifications en attente, regroupées par membre';

    public function handle(): int
    {
        $due = Notification::query()
            ->due()
            ->with('user')
            ->limit((int) $this->option('limit'))
            ->get();

        if ($due->isEmpty()) {
            $this->info('Rien à envoyer.');

            return self::SUCCESS;
        }

        $sent = 0;

        foreach ($due->groupBy('user_id') as $messages) {
            $sent += $this->deliver($messages);
        }

        $this->info("{$sent} message(s) traité(s) pour {$due->groupBy('user_id')->count()} membre(s).");

        return self::SUCCESS;
    }

    /** @param  Collection<int, Notification>  $messages */
    private function deliver(Collection $messages): int
    {
        $user = $messages->first()->user;
        $byMail = $messages->filter(fn (Notification $message) => $message->channel === NotificationChannel::Mail);

        if ($byMail->isNotEmpty() && $user?->email !== null) {
            try {
                Mail::to($user->email)->send(new NotificationDigestMail($byMail->values(), $user->name));
            } catch (\Throwable $exception) {
                // L'e-mail a échoué : le message reste dans l'application, et la raison est consignée.
                Log::warning('Notifications : e-mail non envoyé', ['user' => $user->id, 'raison' => $exception->getMessage()]);

                $byMail->each(fn (Notification $message) => $message->update([
                    'channel' => NotificationChannel::App,
                    'failure_reason' => 'E-mail non envoyé : le message reste dans l’application.',
                ]));
            }
        }

        $messages->each(fn (Notification $message) => $message->update([
            'status' => Notification::SENT,
            'sent_at' => now(),
        ]));

        return $messages->count();
    }
}
