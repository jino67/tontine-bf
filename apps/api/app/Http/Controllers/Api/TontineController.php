<?php

namespace App\Http\Controllers\Api;

use App\Enums\Frequency;
use App\Enums\TontineType;
use App\Http\Controllers\Concerns\AuthorizesOrganizationRoles;
use App\Http\Controllers\Controller;
use App\Http\Resources\TontineResource;
use App\Models\Organization;
use App\Models\Tontine;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Support\Arr;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\Rule;

class TontineController extends Controller
{
    use AuthorizesOrganizationRoles;

    public function index(Request $request, Organization $organization): AnonymousResourceCollection
    {
        $membership = $this->membership($request);

        $tontines = $organization->tontines()
            ->when(
                ! $membership->role->canRecordContributions(),
                fn ($query) => $query->whereHas('members', fn ($members) => $members->where('user_id', $membership->user_id)),
            )
            ->withCount('members')
            ->latest('id')
            ->get();

        return TontineResource::collection($tontines);
    }

    public function store(Request $request, Organization $organization): JsonResponse
    {
        $this->ensureCanManage($request);

        $type = is_string($request->input('type')) ? TontineType::tryFrom($request->input('type')) : null;

        $data = $request->validate([
            'name' => ['required', 'string', 'max:120'],
            'type' => ['required', Rule::enum(TontineType::class)],
            'amount' => ['required', 'integer', 'min:100', 'max:10000000'],
            'frequency' => ['required', Rule::enum(Frequency::class)],
            'starts_on' => ['required', 'date', 'after_or_equal:today'],
            // Pour les tontines à bénéficiaires, le nombre de cycles découle du nombre de parts.
            'cycles_count' => [Rule::requiredIf($type !== null && ! $type->hasBeneficiaries()), 'nullable', 'integer', 'min:1', 'max:520'],
            'max_members' => ['nullable', 'integer', 'min:2', 'max:500'],
            'goal' => ['nullable', 'string', 'max:255'],
            'creator_joins' => ['sometimes', 'boolean'],
        ]);

        $tontine = DB::transaction(function () use ($data, $type, $organization, $request) {
            $tontine = $organization->tontines()->create([
                ...Arr::except($data, ['creator_joins', 'cycles_count', 'max_members']),
                'cycles_count' => $type->hasBeneficiaries() ? null : $data['cycles_count'],
                'max_members' => $type === TontineType::PersonalSavings ? 1 : ($data['max_members'] ?? null),
                'created_by' => $request->user()->id,
            ]);

            if ($data['creator_joins'] ?? true) {
                $tontine->addMember($request->user(), position: 1);
            }

            return $tontine;
        });

        return TontineResource::make($tontine->load('members.user')->loadCount('members'))
            ->response()
            ->setStatusCode(201);
    }

    public function show(Request $request, Organization $organization, Tontine $tontine): TontineResource
    {
        $this->ensureCanView($request, $tontine);

        return TontineResource::make($tontine->load([
            'members' => fn ($query) => $query->orderByRaw('position is null')->orderBy('position')->orderBy('id'),
            'members.user',
        ])->loadCount('members'));
    }
}
