<?php

namespace App\Services\Otp;

interface OtpSender
{
    /** Canal annoncé à l'application : log, mail, puis whatsapp ou sms quand ils seront branchés. */
    public function channel(): string;

    /** @param  string|null  $email  adresse qui reçoit le code, pour le canal mail */
    public function send(string $phone, string $code, ?string $email = null): void;
}
