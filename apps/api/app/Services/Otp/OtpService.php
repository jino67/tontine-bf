<?php

namespace App\Services\Otp;

use App\Models\OtpCode;
use App\Models\User;
use App\Support\PhoneNumber;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\RateLimiter;
use Illuminate\Validation\ValidationException;

class OtpService
{
    private const TTL_MINUTES = 10;

    private const MAX_ATTEMPTS = 5;

    private const MAX_REQUESTS = 3;

    private const REQUEST_WINDOW_SECONDS = 600;

    public function __construct(private OtpSender $sender) {}

    /**
     * Envoie un code et indique où il est parti.
     *
     * Par e-mail, le code part à l'adresse déjà liée au numéro. À la première connexion, il part à
     * l'adresse saisie, qui n'est liée au compte qu'une fois le code vérifié.
     *
     * @return array{channel: string, destination: ?string}
     */
    public function send(string $phone, ?string $email = null): array
    {
        if ($this->isTestPhone($phone)) {
            $this->store($phone, (string) config('services.otp.test_code'));

            return ['channel' => 'test', 'destination' => null];
        }

        $linkedEmail = null;
        $destination = null;

        if ($this->sender->channel() === 'mail') {
            $linkedEmail = User::where('phone', $phone)->value('email');
            $destination = $linkedEmail ?? $email;

            if ($destination === null) {
                throw ValidationException::withMessages(['email' => 'Saisissez votre adresse e-mail pour recevoir le code.']);
            }
        }

        $key = 'otp-request:'.$phone;

        if (RateLimiter::tooManyAttempts($key, self::MAX_REQUESTS)) {
            $minutes = (int) ceil(RateLimiter::availableIn($key) / 60);
            abort(429, "Trop de demandes de code. Réessayez dans {$minutes} min.");
        }

        RateLimiter::hit($key, self::REQUEST_WINDOW_SECONDS);

        $code = str_pad((string) random_int(0, 999999), 6, '0', STR_PAD_LEFT);
        $this->store($phone, $code);

        if ($destination !== null && $linkedEmail === null) {
            Cache::put(self::pendingEmailKey($phone), $destination, now()->addMinutes(self::TTL_MINUTES));
        }

        $this->sender->send($phone, $code, $destination);

        return ['channel' => $this->sender->channel(), 'destination' => $destination];
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
        $pendingEmail = Cache::pull(self::pendingEmailKey($phone));
        $changes = [];

        // Un code reçu par e-mail, ou un code de test, ne prouve pas que le numéro appartient au membre.
        if ($user->phone_verified_at === null && $this->sender->channel() !== 'mail' && ! $this->isTestPhone($phone)) {
            $changes['phone_verified_at'] = now();
        }

        if ($user->email === null && is_string($pendingEmail)) {
            $changes['email'] = $pendingEmail;
        }

        if ($changes !== []) {
            $user->forceFill($changes)->save();
        }

        return $user;
    }

    /** Numéros de test : code fixe, rien n'est envoyé. Toujours ignorés en production. */
    private function isTestPhone(string $phone): bool
    {
        if (app()->isProduction() || preg_match('/^\d{6}$/', (string) config('services.otp.test_code')) !== 1) {
            return false;
        }

        $phones = array_map(
            fn (string $number) => PhoneNumber::normalize(trim($number)),
            explode(',', (string) config('services.otp.test_phones')),
        );

        return in_array($phone, $phones, true);
    }

    private function store(string $phone, string $code): void
    {
        // Un seul code valide à la fois par numéro.
        OtpCode::where('phone', $phone)->whereNull('consumed_at')->update(['consumed_at' => now()]);

        OtpCode::create([
            'phone' => $phone,
            'code_hash' => self::hash($code),
            'expires_at' => now()->addMinutes(self::TTL_MINUTES),
        ]);
    }

    private static function pendingEmailKey(string $phone): string
    {
        return 'otp-email:'.$phone;
    }

    private static function hash(string $code): string
    {
        return hash_hmac('sha256', $code, (string) config('app.key'));
    }
}
