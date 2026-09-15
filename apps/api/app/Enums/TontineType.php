<?php

namespace App\Enums;

enum TontineType: string
{
    case Rotative = 'rotative';
    case DrawOrder = 'tirage_ordre';
    case GroupSavings = 'epargne_groupe';
    case SolidarityPot = 'cagnotte_solidaire';
    case PersonalSavings = 'epargne_perso';

    /** Chaque part reçoit la cagnotte une fois : un cycle par part. */
    public function hasBeneficiaries(): bool
    {
        return $this === self::Rotative || $this === self::DrawOrder;
    }

    public function minMembers(): int
    {
        return $this === self::PersonalSavings ? 1 : 2;
    }
}
