<?php

use App\Enums\Role;
use App\Enums\TontineType;
use App\Models\Cagnotte;
use App\Models\Organization;
use App\Models\Tontine;

function publicTontine(Organization $organization, int $creatorId, array $attributes = []): Tontine
{
    return Tontine::factory()->for($organization)->create([
        'created_by' => $creatorId,
        'name' => 'Tontine du marché',
        'type' => TontineType::Rotative,
        'amount' => 5000,
        'max_members' => 12,
        'visibility' => 'publique',
        'join_policy' => 'sur_demande',
        ...$attributes,
    ]);
}

it('rend une tontine partageable et renvoie son lien', function () {
    $organization = Organization::factory()->create();
    $admin = actingAsUser(memberOf($organization, Role::Admin));
    $tontine = Tontine::factory()->for($organization)->create(['created_by' => $admin->id]);

    expect($tontine->visibility->value)->toBe('privee')
        ->and($tontine->share_code)->toBeNull();

    $url = $this->putJson("/api/v1/orgs/{$organization->id}/tontines/{$tontine->id}/sharing", [
        'visibility' => 'publique',
        'join_policy' => 'sur_demande',
    ])
        ->assertOk()
        ->assertJsonPath('data.visibility', 'publique')
        ->assertJsonPath('data.join_policy', 'sur_demande')
        ->json('data.share_url');

    expect($url)->toStartWith(rtrim(config('app.url'), '/').'/t/');

    // Le code ne change pas quand on rejoue le réglage : un lien déjà envoyé continue de marcher.
    $again = $this->putJson("/api/v1/orgs/{$organization->id}/tontines/{$tontine->id}/sharing", ['visibility' => 'lien'])
        ->assertOk()
        ->json('data.share_url');

    expect($again)->toBe($url);
});

it('laisse lire la fiche publique sans connexion, sans rien dire des membres', function () {
    $organization = Organization::factory()->create(['visibility' => 'publique']);
    $owner = memberOf($organization, Role::Owner);
    $awa = memberOf($organization);
    $tontine = publicTontine($organization, $owner->id);
    $tontine->addMember($awa, 1, 1);
    $code = $tontine->ensureShareCode();

    $response = $this->getJson("/api/v1/links/{$code}")
        ->assertOk()
        ->assertJsonPath('type', 'tontine')
        ->assertJsonPath('data.name', 'Tontine du marché')
        ->assertJsonPath('data.amount', 5000)
        ->assertJsonPath('data.members_count', 1)
        ->assertJsonPath('data.places_left', 11)
        ->assertJsonPath('data.accepts_requests', true)
        ->assertJsonPath('data.organization', $organization->name)
        ->assertJsonPath('data.creator', $owner->name)
        ->assertJsonMissingPath('data.members');

    expect($response->content())->not->toContain($awa->phone)->not->toContain($awa->name);
});

it('cache le nom de l’organisation restée privée', function () {
    $organization = Organization::factory()->create();
    $owner = memberOf($organization, Role::Owner);
    $code = publicTontine($organization, $owner->id)->ensureShareCode();

    $this->getJson("/api/v1/links/{$code}")->assertOk()->assertJsonPath('data.organization', null);
});

it('coupe le lien dès que l’objet redevient privé', function () {
    $organization = Organization::factory()->create();
    $owner = memberOf($organization, Role::Owner);
    $tontine = publicTontine($organization, $owner->id);
    $code = $tontine->ensureShareCode();

    $this->getJson("/api/v1/links/{$code}")->assertOk();

    $tontine->update(['visibility' => 'privee']);

    $this->getJson("/api/v1/links/{$code}")->assertNotFound();
    $this->get("/t/{$code}")->assertNotFound();
});

it('affiche la page de partage d’une cagnotte et propose l’installation', function () {
    config(['services.app_links.apk_url' => 'https://exemple.bf/tontine-bf.apk']);
    $organization = Organization::factory()->create();
    $owner = memberOf($organization, Role::Owner);
    $cagnotte = Cagnotte::factory()->for($organization)->create([
        'created_by' => $owner->id,
        'title' => 'Cagnotte du vendredi',
        'visibility' => 'publique',
    ]);
    $code = $cagnotte->ensureShareCode();

    $this->get("/c/{$code}")
        ->assertOk()
        ->assertSee('Cagnotte du vendredi')
        ->assertSee('Ouvrir dans l’application', false)
        ->assertSee('https://exemple.bf/tontine-bf.apk')
        ->assertSee($code);

    // La lettre du chemin doit correspondre au type de l'objet.
    $this->get("/t/{$code}")->assertNotFound();
});

it('résout aussi un code d’invitation', function () {
    $organization = Organization::factory()->create(['visibility' => 'publique']);
    actingAsUser(memberOf($organization, Role::Admin));

    $code = $this->postJson("/api/v1/orgs/{$organization->id}/invitations", [])
        ->assertCreated()
        ->json('data.code');

    $this->getJson("/api/v1/links/{$code}")
        ->assertOk()
        ->assertJsonPath('type', 'invitation')
        ->assertJsonPath('data.usable', true)
        ->assertJsonPath('data.organization', $organization->name);
});

it('réserve les réglages de partage aux responsables', function () {
    $organization = Organization::factory()->create();
    $owner = memberOf($organization, Role::Owner);
    $tontine = Tontine::factory()->for($organization)->create(['created_by' => $owner->id]);

    actingAsUser(memberOf($organization));

    $this->putJson("/api/v1/orgs/{$organization->id}/tontines/{$tontine->id}/sharing", ['visibility' => 'publique'])
        ->assertForbidden();
});

it('refuse une règle d’adhésion sur une cagnotte et une valeur inconnue', function () {
    $organization = Organization::factory()->create();
    $admin = actingAsUser(memberOf($organization, Role::Admin));
    $cagnotte = Cagnotte::factory()->for($organization)->create(['created_by' => $admin->id]);
    $url = "/api/v1/orgs/{$organization->id}/cagnottes/{$cagnotte->id}/sharing";

    $this->putJson($url, ['visibility' => 'lien', 'join_policy' => 'libre'])
        ->assertUnprocessable()
        ->assertJsonValidationErrors('join_policy');

    $this->putJson($url, ['visibility' => 'ouverte-a-tous'])
        ->assertUnprocessable()
        ->assertJsonValidationErrors('visibility');
});

it('publie assetlinks.json quand une empreinte est configurée', function () {
    config([
        'services.app_links.android_package' => 'bf.tontine.app',
        'services.app_links.android_fingerprints' => 'AA:BB:CC, DD:EE:FF',
    ]);

    $this->getJson('/.well-known/assetlinks.json')
        ->assertOk()
        ->assertJsonPath('0.target.package_name', 'bf.tontine.app')
        ->assertJsonPath('0.target.sha256_cert_fingerprints', ['AA:BB:CC', 'DD:EE:FF']);

    config(['services.app_links.android_fingerprints' => '']);

    $this->getJson('/.well-known/assetlinks.json')->assertOk()->assertExactJson([]);
});
