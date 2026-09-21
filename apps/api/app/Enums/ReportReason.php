<?php

namespace App\Enums;

/** Motifs de signalement d'une fiche publique. */
enum ReportReason: string
{
    case Scam = 'arnaque';
    case Misleading = 'trompeur';
    case Amounts = 'montants_irrealistes';
    case Impersonation = 'usurpation';
    case Other = 'autre';

    public function label(): string
    {
        return match ($this) {
            self::Scam => 'Tentative d’arnaque',
            self::Misleading => 'Contenu trompeur',
            self::Amounts => 'Montants irréalistes',
            self::Impersonation => 'Usurpation d’identité',
            self::Other => 'Autre',
        };
    }
}
