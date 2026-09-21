<?php

namespace App\Http\Controllers\Api;

use App\Enums\JoinPolicy;
use App\Enums\Visibility;
use App\Http\Controllers\Concerns\AuthorizesOrganizationRoles;
use App\Http\Controllers\Controller;
use App\Http\Resources\CagnotteResource;
use App\Http\Resources\OrganizationResource;
use App\Http\Resources\TontineResource;
use App\Models\Cagnotte;
use App\Models\Organization;
use App\Models\Tontine;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

/** Réglages de partage : qui voit l'objet, et comment on le rejoint. */
class SharingController extends Controller
{
    use AuthorizesOrganizationRoles;

    public function organization(Request $request, Organization $organization): OrganizationResource
    {
        $this->ensureCanManage($request);
        $this->apply($organization, $this->rules($request, withJoinPolicy: true));

        return OrganizationResource::make($organization);
    }

    public function tontine(Request $request, Organization $organization, Tontine $tontine): TontineResource
    {
        $this->ensureCanManage($request);
        $this->apply($tontine, $this->rules($request, withJoinPolicy: true));

        return TontineResource::make($tontine->loadCount('members'));
    }

    public function cagnotte(Request $request, Organization $organization, Cagnotte $cagnotte): CagnotteResource
    {
        $this->ensureCanManage($request);
        $this->apply($cagnotte, $this->rules($request, withJoinPolicy: false));

        return CagnotteResource::make($cagnotte);
    }

    /** @return array<string, string> */
    private function rules(Request $request, bool $withJoinPolicy): array
    {
        return $request->validate([
            'visibility' => ['required', Rule::enum(Visibility::class)],
            'join_policy' => [$withJoinPolicy ? 'sometimes' : 'prohibited', Rule::enum(JoinPolicy::class)],
        ]);
    }

    /** @param  array<string, string>  $data */
    private function apply(Model $model, array $data): void
    {
        $model->forceFill($data)->save();

        if ($model->visibility->isShared()) {
            $model->ensureShareCode();
        }
    }
}
