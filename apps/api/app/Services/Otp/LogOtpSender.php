<?php

namespace App\Services\Otp;

use Illuminate\Support\Facades\Log;

/** Écrit le code dans les logs. Réservé au développement et aux essais : refusé en production. */
class LogOtpSender implements OtpSender
{
    public function channel(): string
    {
        return 'log';
    }

    public function send(string $phone, string $code, ?string $email = null): void
    {
        Log::info("Code OTP pour {$phone} : {$code}");
    }
}
