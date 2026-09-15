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
}
