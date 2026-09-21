<?php

namespace App\Enums;

/** Qui supporte les frais de service d'une opération. */
enum FeePayer: string
{
    /** Celui qui lance l'opération : les frais s'ajoutent au montant. */
    case Payer = 'payeur';

    /** Celui qui reçoit : les frais sont retenus sur la somme remise. */
    case Beneficiary = 'beneficiaire';

    /** L'organisation absorbe les frais à la place de son membre. */
    case Organization = 'organisation';

    /** La plateforme ne facture rien sur cette opération. */
    case Platform = 'plateforme';

    public function label(): string
    {
        return match ($this) {
            self::Payer => 'le payeur',
            self::Beneficiary => 'le bénéficiaire',
            self::Organization => "l'organisation",
            self::Platform => 'la plateforme',
        };
    }

    /** Vrai quand les frais s'ajoutent au montant au lieu d'être retenus dessus. */
    public function addsToAmount(): bool
    {
        return $this === self::Payer || $this === self::Organization;
    }
}
