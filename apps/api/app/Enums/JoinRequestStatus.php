<?php

namespace App\Enums;

enum JoinRequestStatus: string
{
    case Pending = 'en_attente';
    case Approved = 'approuvee';
    case Rejected = 'refusee';
    case Withdrawn = 'retiree';
}
