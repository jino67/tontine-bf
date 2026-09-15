<?php

use App\Enums\Role;
use App\Models\Organization;
use App\Models\Tontine;

it("ne donne jamais accès aux tontines d'une autre organisation", function () {
    ['tontine' => $foreignTontine, 'awa' => $foreignMember] = startedTontine();
    $contribution = contributionOf($foreignTontine, $foreignMember);

    $organization = Organization::factory()->create();
    actingAsUser(memberOf($organization, Role::Owner));

    // Depuis sa propre organisation, la tontine étrangère n'existe pas.
    $this->getJson("/api/v1/orgs/{$organization->id}/tontines/{$foreignTontine->id}")->assertNotFound();
    $this->putJson(
        "/api/v1/orgs/{$organization->id}/tontines/{$foreignTontine->id}/cycles/{$contribution->cycle_id}/contributions/{$contribution->id}",
        ['amount_paid' => 5000, 'method' => 'especes'],
    )->assertNotFound();

    // Depuis l'organisation étrangère, il n'est pas membre.
    $this->getJson(tontineUrl($foreignTontine))->assertForbidden();
    $this->getJson("/api/v1/orgs/{$foreignTontine->organization_id}/tontines")->assertForbidden();

    expect($contribution->refresh()->amount_paid)->toBe(0);
});

it("refuse une cotisation adressée par le chemin d'une autre tontine", function () {
    ['organization' => $organization, 'owner' => $owner, 'treasurer' => $treasurer, 'awa' => $awa, 'tontine' => $tontine] = startedTontine();
    $otherTontine = Tontine::factory()->for($organization)->create(['created_by' => $owner->id]);
    $contribution = contributionOf($tontine, $awa);

    actingAsUser($treasurer);

    $this->putJson(
        tontineUrl($otherTontine, "/cycles/{$contribution->cycle_id}/contributions/{$contribution->id}"),
        ['amount_paid' => 5000, 'method' => 'especes'],
    )->assertNotFound();
});
