<?php

namespace App\Mail;

use App\Models\Notification;
use Illuminate\Mail\Mailable;
use Illuminate\Mail\Mailables\Content;
use Illuminate\Mail\Mailables\Envelope;
use Illuminate\Support\Collection;

/**
 * Un seul e-mail par personne et par passage.
 *
 * Un membre de trois tontines reçoit un message le matin, pas trois : c'est la différence
 * entre un rappel utile et un expéditeur que l'on finit par mettre en indésirables.
 *
 * @property Collection<int, Notification> $notifications
 */
class NotificationDigestMail extends Mailable
{
    /** @param  Collection<int, Notification>  $notifications */
    public function __construct(public Collection $notifications, public ?string $name = null) {}

    public function envelope(): Envelope
    {
        $first = $this->notifications->first();
        $subject = $this->notifications->count() === 1
            ? $first->title
            : "Tontine BF : {$this->notifications->count()} choses à savoir";

        return new Envelope(subject: $subject);
    }

    public function content(): Content
    {
        return new Content(view: 'mail.notifications', text: 'mail.notifications-text');
    }
}
