<?php

namespace App\Enums;

/** Où en est une opération de portefeuille. */
enum WalletStatus: string
{
    /** Lancée, en attente du résultat de PayDunya. */
    case Pending = 'en_attente';

    case Succeeded = 'reussie';

    case Failed = 'echouee';

    public function label(): string
    {
        return match ($this) {
            self::Pending => 'en attente',
            self::Succeeded => 'réussie',
            self::Failed => 'échouée',
        };
    }
}
