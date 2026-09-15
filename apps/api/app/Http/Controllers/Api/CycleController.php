<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Concerns\AuthorizesOrganizationRoles;
use App\Http\Controllers\Controller;
use App\Http\Resources\CycleResource;
use App\Models\Cycle;
use App\Models\Organization;
use App\Models\Tontine;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;

class CycleController extends Controller
{
    use AuthorizesOrganizationRoles;

    public function index(Request $request, Organization $organization, Tontine $tontine): AnonymousResourceCollection
    {
        $this->ensureCanView($request, $tontine);

        return CycleResource::collection(
            $tontine->cycles()->with('beneficiary.user')->withContributionTotals()->orderBy('number')->get()
        );
    }

    /** Détail d'un cycle avec toutes les cotisations : chaque membre voit qui a payé. */
    public function show(Request $request, Organization $organization, Tontine $tontine, Cycle $cycle): CycleResource
    {
        $this->ensureCanView($request, $tontine);

        return CycleResource::make(
            $tontine->cycles()
                ->whereKey($cycle->id)
                ->with(['beneficiary.user', 'contributions.member.user'])
                ->withContributionTotals()
                ->firstOrFail()
        );
    }
}
