<?php

namespace App\Enums;

enum PaymentMethod: string
{
    case Cash = 'especes';
    case OrangeMoney = 'orange_money';
    case MoovMoney = 'moov_money';
    case BankTransfer = 'virement';
    case Other = 'autre';

    /** Paiement ou remise passés par PayDunya : jamais saisi à la main pour un encaissement. */
    case PayDunya = 'paydunya';

    /** Réglé avec le solde du portefeuille : jamais saisi à la main non plus. */
    case Wallet = 'portefeuille';

    /** Vrai quand l'argent a réellement transité par l'application, et porte donc des frais de service. */
    public function isOnline(): bool
    {
        return $this === self::PayDunya || $this === self::Wallet;
    }

    /** @return array<int, self> moyens qu'un trésorier peut saisir lui-même. */
    public static function manualCases(): array
    {
        return array_values(array_filter(self::cases(), fn (self $method) => ! $method->isOnline()));
    }
}
