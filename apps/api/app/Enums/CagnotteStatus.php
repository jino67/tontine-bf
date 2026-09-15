<?php

namespace App\Enums;

enum CagnotteStatus: string
{
    case Open = 'ouverte';
    case Closed = 'cloturee';
    case HandedOver = 'remise';
    case Drawn = 'tiree';
    case Cancelled = 'annulee';
}
