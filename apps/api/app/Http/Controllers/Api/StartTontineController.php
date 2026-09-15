<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Concerns\AuthorizesOrganizationRoles;
use App\Http\Controllers\Controller;
use App\Http\Resources\TontineResource;
use App\Models\Organization;
use App\Models\Tontine;
use App\Services\TontineScheduler;
use Illuminate\Http\Request;

class StartTontineController extends Controller
{
    use AuthorizesOrganizationRoles;

    public function __invoke(Request $request, Organization $organization, Tontine $tontine, TontineScheduler $scheduler): TontineResource
    {
        $this->ensureCanManage($request);

        $scheduler->start($tontine);

        return TontineResource::make($organization->tontines()->whereKey($tontine->id)->withProgress()->firstOrFail());
    }
}
