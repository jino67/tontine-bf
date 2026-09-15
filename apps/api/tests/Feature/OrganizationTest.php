<?php

use App\Enums\Role;
use App\Models\Organization;
use App\Models\User;

it('crée une organisation dont le créateur devient propriétaire', function () {
    actingAsUser(User::factory()->create());

    $this->postJson('/api/v1/orgs', ['name' => 'Groupement Wend Panga'])
        ->assertCreated()
        ->assertJsonPath('data.role', 'owner')
        ->assertJsonPath('data.slug', 'groupement-wend-panga')
        ->assertJsonPath('data.plan', 'gratuit');

    Organization::factory()->create();

    $this->getJson('/api/v1/orgs')
        ->assertOk()
        ->assertJsonCount(1, 'data')
        ->assertJsonPath('data.0.role', 'owner');
});

it('refuse les visiteurs non connectés et les non-membres', function () {
    $organization = Organization::factory()->create();

    $this->getJson("/api/v1/orgs/{$organization->id}")->assertUnauthorized();

    actingAsUser(User::factory()->create());

    $this->getJson("/api/v1/orgs/{$organization->id}")->assertForbidden();
});

it('masque le numéro des autres membres pour un simple membre', function () {
    $organization = Organization::factory()->create();
    $owner = memberOf($organization, Role::Owner);
    $awa = memberOf($organization);

    actingAsUser($awa);
    $rows = collect($this->getJson("/api/v1/orgs/{$organization->id}/members")->assertOk()->json('data'));

    expect($rows->firstWhere('user.id', $owner->id)['user']['phone'])->toContain('**')
        ->and($rows->firstWhere('user.id', $awa->id)['user']['phone'])->toBe($awa->phone);

    actingAsUser($owner);
    $rows = collect($this->getJson("/api/v1/orgs/{$organization->id}/members")->json('data'));

    expect($rows->firstWhere('user.id', $awa->id)['user']['phone'])->toBe($awa->phone);
});

it('réserve le changement de rôle au propriétaire', function () {
    $organization = Organization::factory()->create();
    $owner = memberOf($organization, Role::Owner);
    $admin = memberOf($organization, Role::Admin);
    $awa = memberOf($organization);
    $url = fn (User $user) => "/api/v1/orgs/{$organization->id}/members/"
        .$organization->memberships()->where('user_id', $user->id)->value('id');

    actingAsUser($admin);
    $this->patchJson($url($awa), ['role' => 'tresorier'])->assertForbidden();

    actingAsUser($owner);
    $this->patchJson($url($awa), ['role' => 'tresorier'])->assertOk()->assertJsonPath('data.role', 'tresorier');
    $this->patchJson($url($awa), ['role' => 'owner'])->assertUnprocessable();
    $this->patchJson($url($owner), ['role' => 'membre'])->assertUnprocessable();
});
