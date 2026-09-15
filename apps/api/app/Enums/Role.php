<?php

namespace App\Enums;

enum Role: string
{
    case Owner = 'owner';
    case Admin = 'admin';
    case Treasurer = 'tresorier';
    case Member = 'membre';

    /** Créer et configurer les tontines, inviter des membres. */
    public function canManage(): bool
    {
        return $this === self::Owner || $this === self::Admin;
    }

    /** Enregistrer les paiements et voir toutes les tontines de l'organisation. */
    public function canRecordContributions(): bool
    {
        return $this->canManage() || $this === self::Treasurer;
    }
}
