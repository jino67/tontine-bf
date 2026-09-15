<?php

namespace App\Enums;

enum ContributionStatus: string
{
    case Pending = 'en_attente';
    case Recorded = 'enregistree';
    case Confirmed = 'confirmee';
}
