<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\MyContributionResource;
use App\Models\Contribution;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;

/** Échéancier personnel : toutes les cotisations du membre connecté, de la plus proche à la plus lointaine. */
class MyContributionController extends Controller
{
    public function __invoke(Request $request): AnonymousResourceCollection
    {
        $data = $request->validate([
            'organization_id' => ['nullable', 'integer'],
        ]);

        $contributions = Contribution::query()
            ->select('contributions.*')
            ->join('cycles', 'cycles.id', '=', 'contributions.cycle_id')
            ->whereHas('member', fn ($members) => $members->where('user_id', $request->user()->id))
            ->when(
                $data['organization_id'] ?? null,
                fn ($query, $organizationId) => $query->where('contributions.organization_id', $organizationId),
            )
            ->with('cycle.tontine')
            ->orderBy('cycles.due_on')
            ->orderBy('contributions.id')
            ->limit(200)
            ->get();

        return MyContributionResource::collection($contributions);
    }
}
