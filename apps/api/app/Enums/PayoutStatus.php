<?php

namespace App\Enums;

enum PayoutStatus: string
{
    case Processing = 'en_cours';
    case Succeeded = 'reussie';
    case Failed = 'echouee';
}
