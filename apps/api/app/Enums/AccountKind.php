<?php

namespace App\Enums;

/**
 * Nature d'un compte du grand livre.
 *
 * Le sens du solde en dépend : le compte de règlement chez PayDunya est un avoir, il grandit
 * au débit ; un solde de membre est une dette de la plateforme envers lui, il grandit au crédit.
 */
enum AccountKind: string
{
    /** Solde d'un membre. */
    case Member = 'membre';

    /** Argent d'une organisation : cotisations encaissées, en attente du versement d'un tour. */
    case Organization = 'organisation';

    /** Argent d'une cagnotte, en attente du partage ou de la remise. */
    case Cagnotte = 'cagnotte';

    /** Frais de service acquis à la plateforme. */
    case Revenue = 'revenus';

    /** Argent détenu chez PayDunya, entre l'encaissement et le reversement. */
    case Settlement = 'reglement';

    /** Écarts constatés et sommes gelées le temps d'un litige. */
    case Suspense = 'attente';

    /** Vrai pour les comptes d'avoirs, dont le solde grandit au débit. */
    public function isDebitNormal(): bool
    {
        return $this === self::Settlement;
    }

    public function label(): string
    {
        return match ($this) {
            self::Member => 'Solde d’un membre',
            self::Organization => 'Compte d’une organisation',
            self::Cagnotte => 'Compte d’une cagnotte',
            self::Revenue => 'Frais de service',
            self::Settlement => 'Compte de règlement PayDunya',
            self::Suspense => 'Compte d’attente',
        };
    }
}
