<?php

namespace App\Enums;

enum CagnotteMode: string
{
    /** Collecte remise à un bénéficiaire désigné. */
    case Solidarity = 'solidaire';

    /** Participations converties en tickets, gagnants tirés au sort. */
    case Prize = 'gagnants';
}
