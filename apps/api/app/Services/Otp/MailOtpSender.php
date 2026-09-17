<?php

namespace App\Services\Otp;

use App\Mail\OtpCodeMail;
use Illuminate\Support\Facades\Mail;
use Symfony\Component\Mailer\Exception\TransportExceptionInterface;

/** Envoie le code par e-mail, en attendant WhatsApp ou le SMS. */
class MailOtpSender implements OtpSender
{
    public function channel(): string
    {
        return 'mail';
    }

    public function send(string $phone, string $code, ?string $email = null): void
    {
        try {
            Mail::to((string) $email)->send(new OtpCodeMail($code));
        } catch (TransportExceptionInterface $exception) {
            report($exception);

            abort(503, 'L’e-mail contenant le code n’a pas pu être envoyé. Réessayez dans quelques minutes.');
        }
    }
}
