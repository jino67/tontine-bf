<?php

namespace App\Http\Controllers\Concerns;

use App\Models\Membership;
use App\Models\Tontine;
use Illuminate\Http\Request;

trait AuthorizesOrganizationRoles
{
    protected function membership(Request $request): Membership
    {
        return $request->attributes->get('membership');
    }

    protected function ensureCanManage(Request $request): void
    {
        abort_unless(
            $this->membership($request)->role->canManage(),
            403,
            "Action réservée aux responsables de l'organisation.",
        );
    }

    protected function ensureCanRecord(Request $request): void
    {
        abort_unless(
            $this->membership($request)->role->canRecordContributions(),
            403,
            'Action réservée au trésorier et aux responsables.',
        );
    }

    /** Les responsables et le trésorier voient toutes les tontines, les membres seulement les leurs. */
    protected function ensureCanView(Request $request, Tontine $tontine): void
    {
        $membership = $this->membership($request);

        abort_unless(
            $membership->role->canRecordContributions() || $tontine->hasMember($membership->user_id),
            403,
            'Vous ne participez pas à cette tontine.',
        );
    }
}
