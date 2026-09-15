<?php

namespace App\Enums;

enum PaymentMethod: string
{
    case Cash = 'especes';
    case OrangeMoney = 'orange_money';
    case MoovMoney = 'moov_money';
    case BankTransfer = 'virement';
    case Other = 'autre';
}
