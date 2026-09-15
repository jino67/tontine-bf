<?php

use App\Enums\Role;
use App\Models\Contribution;
use App\Models\Organization;
use App\Models\Tontine;
use App\Models\User;

it('permet à un responsable de créer une tontine dont il devient membre', function () {
    $organization = Organization::factory()->create();
    $admin = actingAsUser(memberOf($organization, Role::Admin));

    $this->postJson("/api/v1/orgs/{$organization->id}/tontines", [
        'name' => 'Tontine du marché de Rood Woko',
        'type' => 'rotative',
        'amount' => 5000,
        'frequency' => 'hebdomadaire',
        'starts_on' => now()->addWeek()->toDateString(),
        'max_members' => 12,
    ])
        ->assertCreated()
        ->assertJsonPath('data.status', 'brouillon')
        ->assertJsonPath('data.cycles_count', null)
        ->assertJsonPath('data.members_count', 1)
        ->assertJsonPath('data.members.0.user.id', $admin->id);
});

it('refuse la création de tontine à un simple membre', function () {
    $organization = Organization::factory()->create();
    actingAsUser(memberOf($organization));

    $this->postJson("/api/v1/orgs/{$organization->id}/tontines", [
        'name' => 'Ma tontine',
        'type' => 'rotative',
        'amount' => 5000,
        'frequency' => 'mensuel',
        'starts_on' => now()->addWeek()->toDateString(),
    ])->assertForbidden();
});

it('exige le nombre de cycles pour une épargne de groupe', function () {
    $organization = Organization::factory()->create();
    actingAsUser(memberOf($organization, Role::Owner));

    $this->postJson("/api/v1/orgs/{$organization->id}/tontines", [
        'name' => 'Épargne rentrée scolaire',
        'type' => 'epargne_groupe',
        'amount' => 2000,
        'frequency' => 'mensuel',
        'starts_on' => now()->addWeek()->toDateString(),
    ])->assertUnprocessable()->assertJsonValidationErrors('cycles_count');
});

it('ne montre à un membre que les tontines auxquelles il participe', function () {
    ['organization' => $organization, 'owner' => $owner, 'treasurer' => $treasurer, 'awa' => $awa] = startedTontine();
    Tontine::factory()->for($organization)->create(['created_by' => $owner->id]);

    actingAsUser($awa);
    $this->getJson("/api/v1/orgs/{$organization->id}/tontines")->assertOk()->assertJsonCount(1, 'data');

    actingAsUser($treasurer);
    $this->getJson("/api/v1/orgs/{$organization->id}/tontines")->assertOk()->assertJsonCount(2, 'data');
});

it("inscrit un membre de l'organisation mais refuse une personne extérieure", function () {
    $organization = Organization::factory()->create();
    $admin = actingAsUser(memberOf($organization, Role::Admin));
    $awa = memberOf($organization);
    $tontine = Tontine::factory()->for($organization)->create(['created_by' => $admin->id]);

    $this->postJson(tontineUrl($tontine, '/members'), ['user_id' => $awa->id, 'shares' => 2])
        ->assertCreated()
        ->assertJsonPath('data.shares', 2);

    $this->postJson(tontineUrl($tontine, '/members'), ['user_id' => User::factory()->create()->id])
        ->assertUnprocessable()
        ->assertJsonValidationErrors('user_id');
});

it("démarre une tontine rotative avec un cycle par part, dans l'ordre de passage", function () {
    $organization = Organization::factory()->create();
    $admin = memberOf($organization, Role::Admin);
    [$awa, $binta, $cheick] = [memberOf($organization), memberOf($organization), memberOf($organization)];

    $tontine = Tontine::factory()->for($organization)->create([
        'created_by' => $admin->id,
        'amount' => 5000,
        'frequency' => 'hebdomadaire',
        'starts_on' => '2026-10-05',
    ]);
    $tontine->addMember($binta, position: 2);
    $tontine->addMember($awa, shares: 2, position: 1);
    $tontine->addMember($cheick);

    actingAsUser($admin);
    $this->postJson(tontineUrl($tontine, '/start'))
        ->assertOk()
        ->assertJsonPath('data.status', 'active')
        ->assertJsonPath('data.cycles_count', 4);

    $cycles = $tontine->cycles()->orderBy('number')->get();
    $memberId = $tontine->members()->pluck('id', 'user_id');

    expect($cycles->map(fn ($cycle) => $cycle->due_on->toDateString())->all())
        ->toBe(['2026-10-05', '2026-10-12', '2026-10-19', '2026-10-26'])
        ->and($cycles->pluck('beneficiary_member_id')->all())
        ->toBe([$memberId[$awa->id], $memberId[$awa->id], $memberId[$binta->id], $memberId[$cheick->id]])
        ->and(Contribution::count())->toBe(12)
        ->and(contributionOf($tontine, $awa)->amount_due)->toBe(10000)
        ->and(contributionOf($tontine, $binta)->amount_due)->toBe(5000);

    $this->postJson(tontineUrl($tontine, '/start'))->assertUnprocessable();
});

it('refuse de démarrer une tontine de groupe avec un seul membre', function () {
    $organization = Organization::factory()->create();
    $admin = actingAsUser(memberOf($organization, Role::Admin));
    $tontine = Tontine::factory()->for($organization)->create(['created_by' => $admin->id]);
    $tontine->addMember($admin);

    $this->postJson(tontineUrl($tontine, '/start'))->assertUnprocessable();

    expect($tontine->cycles()->count())->toBe(0);
});
