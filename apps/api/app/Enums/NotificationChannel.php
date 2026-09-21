<?php

namespace App\Enums;

/**
 * Par où part un message, du moins cher au plus cher.
 *
 * Seuls « app » et « mail » sont branchés aujourd'hui. Les autres sont déjà nommés pour que
 * l'historique reste lisible le jour où ils s'ouvriront : un message envoyé par WhatsApp
 * doit rester identifiable comme tel des mois plus tard.
 */
enum NotificationChannel: string
{
    /** Visible à l'ouverture de l'application. Gratuit, mais insuffisant seul. */
    case App = 'application';

    /** Notification Android (Firebase). Gratuit, demande une clé. */
    case Push = 'push';

    /** Récapitulatifs et messages importants. Gratuit avec la boîte de l'hébergeur. */
    case Mail = 'email';

    /** Payé au message : réservé aux relances de paiement. */
    case WhatsApp = 'whatsapp';

    /** Le plus cher : à garder pour les retards importants. */
    case Sms = 'sms';

    public function label(): string
    {
        return match ($this) {
            self::App => 'dans l’application',
            self::Push => 'notification Android',
            self::Mail => 'e-mail',
            self::WhatsApp => 'WhatsApp',
            self::Sms => 'SMS',
        };
    }

    /** Vrai pour les canaux réellement branchés sur ce serveur. */
    public function isAvailable(): bool
    {
        return match ($this) {
            self::App => true,
            self::Mail => config('mail.default') !== null,
            self::Push, self::WhatsApp, self::Sms => false,
        };
    }
}
