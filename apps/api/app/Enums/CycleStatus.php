<?php

namespace App\Enums;

enum CycleStatus: string
{
    case Upcoming = 'a_venir';
    case Open = 'en_cours';
    case Settled = 'regle';
}
