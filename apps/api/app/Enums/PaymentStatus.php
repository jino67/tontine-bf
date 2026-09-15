<?php

namespace App\Enums;

enum PaymentStatus: string
{
    case Pending = 'en_attente';
    case Paid = 'payee';
    case Cancelled = 'annulee';
    case Failed = 'echouee';
}
