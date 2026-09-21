<?php

namespace App\Models\Concerns;

/**
 * Code court et adresse de partage d'un objet.
 *
 * Le modèle qui l'utilise déclare la lettre de son chemin public, par exemple
 * `public const SHARE_PATH = 't';` pour https://exemple.bf/t/ABCD2345
 */
trait HasShareCode
{
    /** Sans 0, O, 1 ni I, comme les codes d'invitation. */
    private const SHARE_ALPHABET = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

    /** Créé au premier partage puis conservé : un lien déjà envoyé continue de fonctionner. */
    public function ensureShareCode(): string
    {
        if ($this->share_code === null) {
            $this->forceFill(['share_code' => self::freshShareCode()])->save();
        }

        return $this->share_code;
    }

    /** Null tant que l'objet est privé : rien à partager, et le lien ne résoudrait pas. */
    public function shareUrl(): ?string
    {
        if ($this->share_code === null || ! $this->visibility->isShared()) {
            return null;
        }

        return rtrim((string) config('app.url'), '/').'/'.static::SHARE_PATH.'/'.$this->share_code;
    }

    private static function freshShareCode(): string
    {
        do {
            $code = '';
            for ($i = 0; $i < 8; $i++) {
                $code .= self::SHARE_ALPHABET[random_int(0, strlen(self::SHARE_ALPHABET) - 1)];
            }
        } while (static::where('share_code', $code)->exists());

        return $code;
    }
}
