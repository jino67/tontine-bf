<?php

namespace App\Enums;

use Carbon\CarbonImmutable;

enum Frequency: string
{
    case Daily = 'quotidien';
    case Weekly = 'hebdomadaire';
    case Monthly = 'mensuel';

    /** Échéance du cycle d'index $index (0 pour le premier), calculée depuis la date de début. */
    public function dueDate(CarbonImmutable $start, int $index): CarbonImmutable
    {
        return match ($this) {
            self::Daily => $start->addDays($index),
            self::Weekly => $start->addWeeks($index),
            self::Monthly => $start->addMonthsNoOverflow($index),
        };
    }
}
