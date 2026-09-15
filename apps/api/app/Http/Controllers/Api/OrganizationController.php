<?php

namespace App\Http\Controllers\Api;

use App\Enums\Role;
use App\Http\Controllers\Controller;
use App\Http\Resources\OrganizationResource;
use App\Models\Organization;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Support\Facades\DB;

class OrganizationController extends Controller
{
    public function index(Request $request): AnonymousResourceCollection
    {
        return OrganizationResource::collection(
            $request->user()->organizations()->orderBy('name')->get()
        );
    }

    public function store(Request $request): JsonResponse
    {
        $data = $request->validate([
            'name' => ['required', 'string', 'min:3', 'max:120'],
        ]);

        $organization = DB::transaction(function () use ($data, $request) {
            $organization = Organization::create([
                'name' => $data['name'],
                'slug' => Organization::uniqueSlug($data['name']),
            ]);

            $organization->memberships()->create(['user_id' => $request->user()->id, 'role' => Role::Owner]);

            return $organization;
        });

        return OrganizationResource::make($organization)
            ->withRole(Role::Owner)
            ->response()
            ->setStatusCode(201);
    }

    public function show(Organization $organization): OrganizationResource
    {
        return OrganizationResource::make($organization);
    }
}
