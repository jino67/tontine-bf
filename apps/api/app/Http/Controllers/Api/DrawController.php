<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Concerns\AuthorizesOrganizationRoles;
use App\Http\Controllers\Controller;
use App\Http\Resources\DrawResource;
use App\Models\Organization;
use App\Models\Tontine;
use App\Services\DrawService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Validation\Rule;

class DrawController extends Controller
{
    use AuthorizesOrganizationRoles;

    public function show(Request $request, Organization $organization, Tontine $tontine): DrawResource
    {
        $this->ensureCanView($request, $tontine);

        return DrawResource::make($tontine->draw ?? abort(404, 'Aucun tirage pour cette tontine.'));
    }

    /** Le responsable lance le tirage et peut attribuer lui-même certains tours, visibles de tous. */
    public function store(Request $request, Organization $organization, Tontine $tontine, DrawService $draws): JsonResponse
    {
        $this->ensureCanManage($request);

        $data = $request->validate([
            'reveal_after' => ['nullable', 'date', 'after_or_equal:now'],
            'designations' => ['nullable', 'array', 'max:520'],
            'designations.*.cycle' => ['required', 'integer', 'min:1', 'distinct'],
            'designations.*.member_id' => [
                'required',
                'integer',
                Rule::exists('tontine_members', 'id')->where('tontine_id', $tontine->id),
            ],
        ]);

        $revealAfter = isset($data['reveal_after']) ? Carbon::parse($data['reveal_after']) : now()->addDay();

        return DrawResource::make($draws->commit($tontine, $request->user(), $revealAfter, $data['designations'] ?? []))
            ->response()
            ->setStatusCode(201);
    }

    /** Tout membre de la tontine peut déclencher la révélation une fois la date passée. */
    public function reveal(Request $request, Organization $organization, Tontine $tontine, DrawService $draws): DrawResource
    {
        $this->ensureCanView($request, $tontine);

        $draw = $tontine->draw ?? abort(404, 'Aucun tirage pour cette tontine.');

        return DrawResource::make($draws->reveal($draw));
    }
}
