<?php

namespace App\Http\Middleware;

use App\Models\Organization;
use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/** Refuse l'accès aux routes /orgs/{organization}/... si l'utilisateur n'appartient pas à l'organisation. */
class EnsureOrganizationMember
{
    public function handle(Request $request, Closure $next): Response
    {
        $organization = $request->route('organization');

        if (! $organization instanceof Organization) {
            $organization = Organization::findOrFail($organization);
        }

        $membership = $organization->memberships()->where('user_id', $request->user()->id)->first();

        abort_if($membership === null, 403, "Vous n'êtes pas membre de cette organisation.");

        $membership->setRelation('organization', $organization)->setRelation('user', $request->user());
        $request->attributes->set('membership', $membership);

        return $next($request);
    }
}
