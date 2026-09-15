<?php

namespace App\Services\Otp;

use App\Models\OtpCode;
use App\Models\User;
use Illuminate\Support\Facades\RateLimiter;
use Illuminate\Validation\ValidationException;

class OtpService
{
    private const TTL_MINUTES = 10;

    private const MAX_ATTEMPTS = 5;

    private const MAX_REQUESTS = 3;

    private const REQUEST_WINDOW_SECONDS = 600;

    public function __construct(private OtpSender $sender) {}

    public function send(string $phone): void
    {
        $key = 'otp-request:'.$phone;

        if (RateLimiter::tooManyAttempts($key, self::MAX_REQUESTS)) {
            $minutes = (int) ceil(RateLimiter::availableIn($key) / 60);
            abort(429, "Trop de demandes de code. Réessayez dans {$minutes} min.");
        }

        RateLimiter::hit($key, self::REQUEST_WINDOW_SECONDS);

        // Un seul code valide à la fois par numéro.
        OtpCode::where('phone', $phone)->whereNull('consumed_at')->update(['consumed_at' => now()]);

        $code = str_pad((string) random_int(0, 999999), 6, '0', STR_PAD_LEFT);

        OtpCode::create([
            'phone' => $phone,
            'code_hash' => self::hash($code),
            'expires_at' => now()->addMinutes(self::TTL_MINUTES),
        ]);

        $this->sender->send($phone, $code);
    }

    /** Vérifie le code et retourne l'utilisateur, créé à sa première connexion. */
    public function verify(string $phone, string $code): User
    {
        $otp = OtpCode::where('phone', $phone)
            ->whereNull('consumed_at')
            ->where('expires_at', '>', now())
            ->latest('id')
            ->first();

        if ($otp === null) {
            throw ValidationException::withMessages(['code' => 'Code invalide ou expiré.']);
        }

        if (! hash_equals($otp->code_hash, self::hash($code))) {
            $otp->increment('attempts');

            if ($otp->attempts >= self::MAX_ATTEMPTS) {
                $otp->update(['consumed_at' => now()]);
            }

            throw ValidationException::withMessages(['code' => 'Code invalide ou expiré.']);
        }

        $otp->update(['consumed_at' => now()]);

        $user = User::firstOrCreate(['phone' => $phone]);

        if ($user->phone_verified_at === null) {
            $user->forceFill(['phone_verified_at' => now()])->save();
        }

        return $user;
    }

    private static function hash(string $code): string
    {
        return hash_hmac('sha256', $code, (string) config('app.key'));
    }
}
