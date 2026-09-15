<?php

namespace App\Enums;

use Carbon\CarbonInterface;

enum CagnotteDuration: string
{
    case Flash = 'flash_24h';
    case Week = 'hebdo_7j';
    case Month = 'mensuelle_30j';
    case Custom = 'personnalisee';

    /** Date de fin pour les durées prédéfinies, null pour une date choisie librement. */
    public function endsAt(CarbonInterface $opensAt): ?CarbonInterface
    {
        return match ($this) {
            self::Flash => $opensAt->copy()->addDay(),
            self::Week => $opensAt->copy()->addDays(7),
            self::Month => $opensAt->copy()->addDays(30),
            self::Custom => null,
        };
    }
}
