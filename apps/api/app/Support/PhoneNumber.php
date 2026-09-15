<?php

namespace App\Support;

final class PhoneNumber
{
    /** Normalise un numéro burkinabè au format E.164 (+226XXXXXXXX). Retourne null si le numéro est invalide. */
    public static function normalize(?string $input): ?string
    {
        if ($input === null) {
            return null;
        }

        $number = preg_replace('/[\s.\-()]/', '', $input);

        if (str_starts_with($number, '00')) {
            $number = '+'.substr($number, 2);
        }

        if (preg_match('/^\d{8}$/', $number)) {
            $number = '+226'.$number;
        }

        return preg_match('/^\+226\d{8}$/', $number) ? $number : null;
    }

    /** +22670123456 devient +226 ** ** 34 56 */
    public static function mask(string $phone): string
    {
        return substr($phone, 0, 4).' ** ** '.substr($phone, -4, 2).' '.substr($phone, -2);
    }
}
