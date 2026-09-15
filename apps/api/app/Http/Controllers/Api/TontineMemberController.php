<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Concerns\AuthorizesOrganizationRoles;
use App\Http\Controllers\Controller;
use App\Http\Resources\TontineMemberResource;
use App\Models\Organization;
use App\Models\Tontine;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class TontineMemberController extends Controller
{
    use AuthorizesOrganizationRoles;

    public function store(Request $request, Organization $organization, Tontine $tontine): JsonResponse
    {
        $this->ensureCanManage($request);

        $data = $request->validate([
            'user_id' => ['required', 'integer', Rule::exists('organization_user', 'user_id')->where('organization_id', $organization->id)],
            'shares' => ['nullable', 'integer', 'min:1', 'max:10'],
            'position' => ['nullable', 'integer', 'min:1', 'max:500'],
        ], [
            'user_id.exists' => "Cette personne n'est pas membre de l'organisation.",
        ]);

        $member = $tontine->addMember(User::findOrFail($data['user_id']), $data['shares'] ?? 1, $data['position'] ?? null);

        return TontineMemberResource::make($member->load('user'))->response()->setStatusCode(201);
    }
}
