<?php

use App\Enums\CagnotteDuration;
use App\Enums\Role;
use App\Models\Cagnotte;
use App\Models\Organization;
use App\Models\User;

function cagnotteUrl(Cagnotte $cagnotte, string $path = ''): string
{
    return "/api/v1/orgs/{$cagnotte->organization_id}/cagnottes/{$cagnotte->id}{$path}";
}

it('crée une cagnotte flash qui se termine 24 heures plus tard', function () {
    $this->freezeTime();
    $organization = Organization::factory()->create();
    actingAsUser(memberOf($organization, Role::Admin));
    $binta = memberOf($organization);

    $this->postJson("/api/v1/orgs/{$organization->id}/cagnottes", [
        'title' => 'Soutien à Binta',
        'duration' => 'flash_24h',
        'target_amount' => 50000,
        'min_amount' => 500,
        'beneficiary_user_id' => $binta->id,
    ])
        ->assertCreated()
        ->assertJsonPath('data.status', 'ouverte')
        ->assertJsonPath('data.accepts_contributions', true)
        ->assertJsonPath('data.beneficiary.type', 'membre')
        ->assertJsonPath('data.beneficiary.name', $binta->name)
        ->assertJsonPath('data.ends_at', now()->addDay()->toIso8601String())
        ->assertJsonPath('data.seconds_left', 86400)
        ->assertJsonPath('data.collected_amount', 0);
});

it('exige une date de fin pour une durée personnalisée et un bénéficiaire', function () {
    $organization = Organization::factory()->create();
    actingAsUser(memberOf($organization, Role::Owner));

    $this->postJson("/api/v1/orgs/{$organization->id}/cagnottes", [
        'title' => 'Fête de fin d’année',
        'duration' => 'personnalisee',
    ])
        ->assertUnprocessable()
        ->assertJsonValidationErrors([
            'ends_at',
            'beneficiary_name' => 'Choisissez un membre bénéficiaire ou indiquez le nom d’une personne extérieure.',
        ]);

    $this->postJson("/api/v1/orgs/{$organization->id}/cagnottes", [
        'title' => 'Fête de fin d’année',
        'duration' => 'personnalisee',
        'ends_at' => now()->addDays(45)->toIso8601String(),
        'beneficiary_name' => 'Comité des fêtes',
    ])
        ->assertCreated()
        ->assertJsonPath('data.beneficiary.type', 'externe')
        ->assertJsonPath('data.beneficiary.name', 'Comité des fêtes');
});

it('réserve la création aux responsables et refuse un bénéficiaire extérieur à l’organisation', function () {
    $organization = Organization::factory()->create();
    $payload = ['title' => 'Soutien', 'duration' => 'hebdo_7j', 'beneficiary_user_id' => User::factory()->create()->id];

    actingAsUser(memberOf($organization));
    $this->postJson("/api/v1/orgs/{$organization->id}/cagnottes", $payload)->assertForbidden();

    actingAsUser(memberOf($organization, Role::Admin));
    $this->postJson("/api/v1/orgs/{$organization->id}/cagnottes", $payload)
        ->assertUnprocessable()
        ->assertJsonValidationErrors('beneficiary_user_id');
});

it('enregistre des participations libres au-dessus du minimum, puis les fait confirmer', function () {
    $organization = Organization::factory()->create();
    $treasurer = memberOf($organization, Role::Treasurer);
    $awa = memberOf($organization);
    $cagnotte = Cagnotte::factory()->for($organization)->create(['created_by' => $treasurer->id, 'min_amount' => 500, 'target_amount' => 10000]);

    actingAsUser($treasurer);
    $this->postJson(cagnotteUrl($cagnotte, '/contributions'), ['user_id' => $awa->id, 'amount' => 300, 'method' => 'especes'])
        ->assertUnprocessable()
        ->assertJsonValidationErrors(['amount' => 'Le champ montant doit être au moins égal à 500.']);

    $contributionId = $this->postJson(cagnotteUrl($cagnotte, '/contributions'), [
        'user_id' => $awa->id,
        'amount' => 2500,
        'method' => 'orange_money',
        'reference' => 'PP260922.0915',
    ])->assertCreated()->assertJsonPath('data.status', 'enregistree')->json('data.id');

    $this->getJson(cagnotteUrl($cagnotte))
        ->assertOk()
        ->assertJsonPath('data.collected_amount', 2500)
        ->assertJsonPath('data.contributions_count', 1)
        ->assertJsonPath('data.contributions.0.user.id', $awa->id);

    actingAsUser($awa);
    $this->postJson(cagnotteUrl($cagnotte, "/contributions/{$contributionId}/confirm"))
        ->assertOk()
        ->assertJsonPath('data.status', 'confirmee');

    actingAsUser($treasurer);
    $this->putJson(cagnotteUrl($cagnotte, "/contributions/{$contributionId}"), ['amount' => 1000, 'method' => 'especes'])
        ->assertUnprocessable();
});

it('ferme la collecte à la date de fin puis trace la remise des fonds jusqu’à la confirmation du bénéficiaire', function () {
    $organization = Organization::factory()->create();
    $admin = memberOf($organization, Role::Admin);
    $awa = memberOf($organization);
    $binta = memberOf($organization);
    $cagnotte = Cagnotte::factory()->for($organization)->create([
        'created_by' => $admin->id,
        'duration' => CagnotteDuration::Flash,
        'ends_at' => now()->addDay(),
        'beneficiary_user_id' => $binta->id,
        'beneficiary_name' => null,
    ]);

    actingAsUser($admin);
    $this->postJson(cagnotteUrl($cagnotte, '/contributions'), ['user_id' => $awa->id, 'amount' => 5000, 'method' => 'especes'])->assertCreated();
    $this->postJson(cagnotteUrl($cagnotte, '/handover'), ['amount' => 5000, 'method' => 'especes'])->assertUnprocessable();

    $this->travel(25)->hours();

    $this->getJson(cagnotteUrl($cagnotte))
        ->assertJsonPath('data.status', 'cloturee')
        ->assertJsonPath('data.accepts_contributions', false)
        ->assertJsonPath('data.seconds_left', 0);
    $this->postJson(cagnotteUrl($cagnotte, '/contributions'), ['user_id' => $awa->id, 'amount' => 1000, 'method' => 'especes'])
        ->assertUnprocessable();

    $this->postJson(cagnotteUrl($cagnotte, '/handover'), ['amount' => 6000, 'method' => 'especes'])
        ->assertUnprocessable()
        ->assertJsonValidationErrors('amount');
    $this->postJson(cagnotteUrl($cagnotte, '/handover'), ['amount' => 5000, 'method' => 'orange_money', 'reference' => 'OM-REMISE-1'])
        ->assertOk()
        ->assertJsonPath('data.status', 'remise')
        ->assertJsonPath('data.handover.amount', 5000)
        ->assertJsonPath('data.handover.confirmed_at', null);

    actingAsUser($awa);
    $this->postJson(cagnotteUrl($cagnotte, '/handover/confirm'))->assertForbidden();

    actingAsUser($binta);
    $this->postJson(cagnotteUrl($cagnotte, '/handover/confirm'))->assertOk();

    expect($cagnotte->refresh()->handover_confirmed_at)->not->toBeNull();
});

it('permet à un responsable de clôturer une cagnotte avant la date prévue', function () {
    $organization = Organization::factory()->create();
    $owner = memberOf($organization, Role::Owner);
    $cagnotte = Cagnotte::factory()->for($organization)->create(['created_by' => $owner->id]);

    actingAsUser(memberOf($organization, Role::Treasurer));
    $this->postJson(cagnotteUrl($cagnotte, '/close'))->assertForbidden();

    actingAsUser($owner);
    $this->postJson(cagnotteUrl($cagnotte, '/close'))->assertOk()->assertJsonPath('data.status', 'cloturee');
    $this->postJson(cagnotteUrl($cagnotte, '/close'))->assertUnprocessable();
});

it("n'expose pas les cagnottes d'une autre organisation", function () {
    $foreign = Cagnotte::factory()->create();
    $organization = Organization::factory()->create();
    actingAsUser(memberOf($organization, Role::Owner));

    $this->getJson("/api/v1/orgs/{$organization->id}/cagnottes/{$foreign->id}")->assertNotFound();
    $this->getJson(cagnotteUrl($foreign))->assertForbidden();
});
