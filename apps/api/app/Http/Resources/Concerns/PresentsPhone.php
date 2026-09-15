<?php

namespace App\Http\Resources\Concerns;

use App\Models\User;
use App\Support\PhoneNumber;
use Illuminate\Http\Request;

trait PresentsPhone
{
    /** Numéro complet pour soi-même, le trésorier et les responsables. Masqué pour les autres membres. */
    protected function phoneFor(Request $request, User $user): string
    {
        $viewer = $request->attributes->get('membership');
        $visible = $request->user()?->id === $user->id
            || ($viewer !== null && $viewer->role->canRecordContributions());

        return $visible ? $user->phone : PhoneNumber::mask($user->phone);
    }
}
