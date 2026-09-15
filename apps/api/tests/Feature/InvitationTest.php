<?php

use App\Enums\Role;
use App\Models\Organization;
use App\Models\Tontine;
use App\Models\User;

it("fait rejoindre l'organisation et la tontine avec un code", function () {
    $organization = Organization::factory()->create();
    $admin = actingAsUser(memberOf($organization, Role::Admin));
    $tontine = Tontine::factory()->for($organization)->create(['created_by' => $admin->id]);

    $code = $this->postJson("/api/v1/orgs/{$organization->id}/invitations", ['tontine_id' => $tontine->id, 'max_uses' => 1])
        ->assertCreated()
        ->json('data.code');

    $newcomer = actingAsUser(User::factory()->create());

    $this->postJson('/api/v1/invitations/'.strtolower($code).'/accept')
        ->assertOk()
        ->assertJsonPath('organization.role', 'membre')
        ->assertJsonPath('tontine.id', $tontine->id);

    expect($tontine->hasMember($newcomer->id))->toBeTrue();

    actingAsUser(User::factory()->create());
    $this->postJson("/api/v1/invitations/{$code}/accept")->assertUnprocessable();
});

it('refuse une invitation expirée', function () {
    $organization = Organization::factory()->create();
    actingAsUser(memberOf($organization, Role::Owner));

    $code = $this->postJson("/api/v1/orgs/{$organization->id}/invitations", ['expires_in_days' => 7])->json('data.code');

    $this->travel(8)->days();
    actingAsUser(User::factory()->create());

    $this->postJson("/api/v1/invitations/{$code}/accept")->assertUnprocessable();
});

it("refuse l'inscription par invitation à une tontine déjà démarrée", function () {
    ['organization' => $organization, 'owner' => $owner, 'tontine' => $tontine] = startedTontine();
    actingAsUser($owner);

    $code = $this->postJson("/api/v1/orgs/{$organization->id}/invitations", ['tontine_id' => $tontine->id])->json('data.code');
    $newcomer = actingAsUser(User::factory()->create());

    $this->postJson("/api/v1/invitations/{$code}/accept")->assertUnprocessable();

    expect($organization->memberships()->where('user_id', $newcomer->id)->exists())->toBeFalse();
});

it("interdit à un simple membre d'inviter, et d'inviter vers la tontine d'une autre organisation", function () {
    ['tontine' => $foreignTontine] = startedTontine();
    $organization = Organization::factory()->create();

    actingAsUser(memberOf($organization));
    $this->postJson("/api/v1/orgs/{$organization->id}/invitations")->assertForbidden();

    actingAsUser(memberOf($organization, Role::Owner));
    $this->postJson("/api/v1/orgs/{$organization->id}/invitations", ['tontine_id' => $foreignTontine->id])
        ->assertUnprocessable()
        ->assertJsonValidationErrors('tontine_id');
});
