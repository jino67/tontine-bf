<?php

namespace App\Enums;

/**
 * Ce qui déclenche un message.
 *
 * Une tontine se tient par les rappels : sans eux, tout repose sur le trésorier qui relance
 * de vive voix. Mais un rappel qu'on ne peut pas couper devient un spam, d'où le réglage
 * par membre et l'interrupteur par tontine.
 */
enum NotificationType: string
{
    /** Trois jours avant l'échéance d'un tour. */
    case ReminderBefore = 'rappel_avant';

    /** Le jour de l'échéance, pour qui n'a pas encore réglé. */
    case ReminderDue = 'rappel_jour';

    /** Après l'échéance, tous les trois jours. */
    case ReminderLate = 'rappel_retard';

    /** Récapitulatif des retards, pour le trésorier. */
    case TreasurerDigest = 'recapitulatif_tresorier';

    /** Le trésorier a enregistré un paiement : le membre le confirme. */
    case PaymentRecorded = 'paiement_enregistre';

    /** Le membre a confirmé : le trésorier le sait. */
    case PaymentConfirmed = 'paiement_confirme';

    /** Le tour est complet : le bénéficiaire va recevoir. */
    case CycleSettled = 'tour_complet';

    /** Argent arrivé sur le solde : tour, gain, remise ou transfert. */
    case WalletCredited = 'solde_credite';

    /** Vingt-quatre heures avant la clôture d'une cagnotte. */
    case CagnotteClosing = 'cagnotte_bientot';

    /** Les gagnants sont connus. */
    case CagnotteDrawn = 'cagnotte_tiree';

    /** Une nouvelle édition d'une série vient de s'ouvrir. */
    case CagnotteRelaunched = 'cagnotte_relancee';

    /** Quelqu'un demande à rejoindre : pour les responsables. */
    case JoinRequested = 'demande_adhesion';

    /** Demande acceptée ou refusée : pour le demandeur. */
    case JoinAnswered = 'demande_tranchee';

    public function label(): string
    {
        return match ($this) {
            self::ReminderBefore => 'Rappel avant échéance',
            self::ReminderDue => 'Rappel le jour de l’échéance',
            self::ReminderLate => 'Relance de retard',
            self::TreasurerDigest => 'Récapitulatif du trésorier',
            self::PaymentRecorded => 'Paiement enregistré',
            self::PaymentConfirmed => 'Paiement confirmé',
            self::CycleSettled => 'Tour complet',
            self::WalletCredited => 'Argent reçu',
            self::CagnotteClosing => 'Cagnotte bientôt close',
            self::CagnotteDrawn => 'Tirage révélé',
            self::CagnotteRelaunched => 'Nouvelle édition',
            self::JoinRequested => 'Demande d’adhésion',
            self::JoinAnswered => 'Réponse à votre demande',
        };
    }

    /**
     * Canal visé, selon ce que le message vaut.
     *
     * Un rappel de routine ne justifie pas un message payant ; une relance de retard ou de
     * l'argent qui bouge, si. Le canal réellement utilisé dépend ensuite de ce qui est branché
     * sur le serveur et de ce que le membre accepte.
     */
    public function preferredChannel(): NotificationChannel
    {
        return match ($this) {
            self::ReminderBefore, self::ReminderDue, self::CagnotteClosing,
            self::CagnotteRelaunched, self::PaymentConfirmed => NotificationChannel::Push,
            self::ReminderLate, self::PaymentRecorded, self::JoinRequested,
            self::JoinAnswered => NotificationChannel::WhatsApp,
            self::TreasurerDigest, self::CycleSettled, self::WalletCredited,
            self::CagnotteDrawn => NotificationChannel::Mail,
        };
    }

    /** Les relances de paiement se coupent tontine par tontine ; le reste est de l'information utile. */
    public function isReminder(): bool
    {
        return in_array($this, [self::ReminderBefore, self::ReminderDue, self::ReminderLate, self::TreasurerDigest], true);
    }

    /**
     * Ce qui ne peut pas attendre le matin : l'argent qui bouge et les tirages.
     * Tout le reste respecte les heures décentes.
     */
    public function isImmediate(): bool
    {
        return in_array($this, [self::WalletCredited, self::CagnotteDrawn, self::PaymentRecorded], true);
    }
}
