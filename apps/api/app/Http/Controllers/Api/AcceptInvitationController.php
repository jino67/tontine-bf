<?php

namespace App\Http\Controllers\Api;

use App\Enums\Role;
use App\Exceptions\DomainRuleException;
use App\Http\Controllers\Controller;
use App\Http\Resources\OrganizationResource;
use App\Http\Resources\TontineResource;
use App\Models\Invitation;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class AcceptInvitationController extends Controller
{
    public function __invoke(Request $request, string $code): JsonResponse
    {
        $user = $request->user();

        [$membership, $tontine] = DB::transaction(function () use ($code, $user) {
            $invitation = Invitation::where('code', strtoupper($code))->lockForUpdate()->first();

            if ($invitation === null || ! $invitation->isUsable()) {
                throw new DomainRuleException('Invitation invalide ou expirée.');
            }

            $membership = $invitation->organization->memberships()->firstOrCreate(
                ['user_id' => $user->id],
                ['role' => Role::Member],
            );
            $joined = $membership->wasRecentlyCreated;
            $tontine = $invitation->tontine;

            if ($tontine !== null && ! $tontine->hasMember($user->id)) {
                $tontine->addMember($user);
                $joined = true;
            }

            if ($joined) {
                $invitation->increment('used_count');
            }

            return [$membership, $tontine];
        });

        return response()->json([
            'organization' => OrganizationResource::make($membership->organization)->withRole($membership->role),
            'tontine' => $tontine ? TontineResource::make($tontine) : null,
        ]);
    }
}
