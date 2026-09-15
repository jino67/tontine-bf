<?php

namespace App\Enums;

enum TontineStatus: string
{
    case Draft = 'brouillon';
    case Active = 'active';
    case Completed = 'terminee';
    case Cancelled = 'annulee';
}
