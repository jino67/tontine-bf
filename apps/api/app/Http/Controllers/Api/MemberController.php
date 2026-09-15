<?php

namespace App\Http\Controllers\Api;

use App\Enums\Role;
use App\Exceptions\DomainRuleException;
use App\Http\Controllers\Concerns\AuthorizesOrganizationRoles;
use App\Http\Controllers\Controller;
use App\Http\Resources\MembershipResource;
use App\Models\Membership;
use App\Models\Organization;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Validation\Rule;

class MemberController extends Controller
{
    use AuthorizesOrganizationRoles;

    public function index(Organization $organization): AnonymousResourceCollection
    {
        return MembershipResource::collection(
            $organization->memberships()->with('user')->orderBy('id')->get()
        );
    }

    public function update(Request $request, Organization $organization, Membership $membership): MembershipResource
    {
        abort_unless($this->membership($request)->role === Role::Owner, 403, 'Seul le propriétaire peut modifier les rôles.');

        if ($membership->role === Role::Owner) {
            throw new DomainRuleException('Le rôle du propriétaire ne peut pas être modifié.');
        }

        $data = $request->validate([
            'role' => ['required', Rule::enum(Role::class)->except(Role::Owner)],
        ]);

        $membership->update(['role' => $data['role']]);

        return MembershipResource::make($membership->load('user'));
    }
}
