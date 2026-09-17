<?php

namespace App\Mail;

use Illuminate\Mail\Mailable;
use Illuminate\Mail\Mailables\Content;
use Illuminate\Mail\Mailables\Envelope;

/** Code de connexion. Il figure aussi dans l'objet, pour se lire directement dans la notification. */
class OtpCodeMail extends Mailable
{
    public function __construct(public string $code) {}

    public function envelope(): Envelope
    {
        return new Envelope(subject: "Votre code de connexion Tontine BF : {$this->code}");
    }

    public function content(): Content
    {
        return new Content(view: 'mail.otp-code', text: 'mail.otp-code-text');
    }
}
