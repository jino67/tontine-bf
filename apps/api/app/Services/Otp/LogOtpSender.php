<?php

namespace App\Services\Otp;

use Illuminate\Support\Facades\Log;

/** Écrit le code dans les logs. Réservé au développement : jamais utilisé en production. */
class LogOtpSender implements OtpSender
{
    public function send(string $phone, string $code): void
    {
        Log::info("Code OTP pour {$phone} : {$code}");
    }
}
