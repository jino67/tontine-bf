<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Concerns\AuthorizesOrganizationRoles;
use App\Http\Controllers\Controller;
use App\Http\Resources\InvitationResource;
use App\Models\Invitation;
use App\Models\Organization;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class InvitationController extends Controller
{
    use AuthorizesOrganizationRoles;

    public function store(Request $request, Organization $organization): JsonResponse
    {
        $this->ensureCanManage($request);

        $data = $request->validate([
            'tontine_id' => ['nullable', 'integer', Rule::exists('tontines', 'id')->where('organization_id', $organization->id)],
            'max_uses' => ['nullable', 'integer', 'min:1', 'max:500'],
            'expires_in_days' => ['nullable', 'integer', 'min:1', 'max:60'],
        ]);

        $invitation = $organization->invitations()->create([
            'tontine_id' => $data['tontine_id'] ?? null,
            'created_by' => $request->user()->id,
            'code' => Invitation::generateCode(),
            'max_uses' => $data['max_uses'] ?? null,
            'expires_at' => now()->addDays($data['expires_in_days'] ?? 7),
        ]);

        return InvitationResource::make($invitation)->response()->setStatusCode(201);
    }
}
