<?php

namespace App\Enums;

/** Les collectes solidaires sont gérées à part, par les cagnottes. */
enum TontineType: string
{
    case Rotative = 'rotative';
    case DrawOrder = 'tirage_ordre';
    case GroupSavings = 'epargne_groupe';
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
