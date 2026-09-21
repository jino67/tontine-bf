<?php

use App\Enums\CagnotteMode;
use App\Enums\PaymentMethod;
use App\Enums\Role;
use App\Enums\Visibility;
use App\Models\Cagnotte;
use App\Models\CagnotteTemplate;
use App\Models\Organization;
use App\Models\User;

function publicCagnotte(Organization $organization, User $creator, array $attributes = []): Cagnotte
{
    return Cagnotte::factory()->for($organization)->create([
        'created_by' => $creator->id,
        'mode' => CagnotteMode::Prize,
        'title' => 'Tombola du vendredi',
        'ticket_price' => 500,
        'min_amount' => 500,
        'winners_count' => 1,
        'prize_split' => [100],
        'beneficiary_name' => null,
        'platform_fee_bp' => 500,
        ...$attributes,
    ]);
}

it('ouvre les cagnottes à tous : un visiteur voit la fiche et participe sans rejoindre le groupe', function () {
    $organization = Organization::factory()->create();
    $creator = memberOf($organization, Role::Admin);
    $cagnotte = publicCagnotte($organization, $creator);

    // Le visiteur n'appartient à aucune organisation.
    $visitor = actingAsUser(User::factory()->create());
    fundWallet($visitor, 5000);

    $this->getJson("/api/v1/cagnottes/{$cagnotte->id}")
        ->assertOk()
        ->assertJsonPath('data.title', 'Tombola du vendredi')
        ->assertJsonPath('data.visibility', 'publique')
        // Une fiche publique ne montre ni les participants, ni ce que chacun a versé.
        ->assertJsonMissingPath('data.contributions');

    $this->postJson("/api/v1/cagnottes/{$cagnotte->id}/pay-with-balance", ['amount' => 1500])
        ->assertCreated()
        ->assertJsonPath('data.type', 'participation')
        ->assertJsonPath('data.amount', 1500);

    $this->getJson("/api/v1/cagnottes/{$cagnotte->id}")
        ->assertJsonPath('data.collected_amount', 1500)
        // 500 le ticket : trois chances.
        ->assertJsonPath('data.my_tickets', 3);

    // Le visiteur reste étranger à l'organisation.
    $this->getJson("/api/v1/orgs/{$organization->id}/cagnottes")->assertForbidden();
});

it('garde une cagnotte privée invisible du dehors', function () {
    $organization = Organization::factory()->create();
    $cagnotte = publicCagnotte($organization, memberOf($organization, Role::Admin), ['visibility' => Visibility::Members]);

    actingAsUser(User::factory()->create());

    $this->getJson("/api/v1/cagnottes/{$cagnotte->id}")->assertNotFound();
    $this->postJson("/api/v1/cagnottes/{$cagnotte->id}/pay-with-balance", ['amount' => 500])->assertNotFound();
});

it('masque une cagnotte signalée trois fois', function () {
    $organization = Organization::factory()->create();
    $cagnotte = publicCagnotte($organization, memberOf($organization, Role::Admin));

    foreach (range(1, 3) as $ignored) {
        actingAsUser(User::factory()->create());
        $this->postJson('/api/v1/reports', ['type' => 'cagnotte', 'id' => $cagnotte->id, 'reason' => 'arnaque'])->assertCreated();
    }

    actingAsUser(User::factory()->create());
    $this->getJson("/api/v1/cagnottes/{$cagnotte->id}")->assertNotFound();
});

it('relance la série après le tirage, et le lien mène toujours à l’édition ouverte', function () {
    $organization = Organization::factory()->create();
    $admin = actingAsUser(memberOf($organization, Role::Admin));

    $first = publicCagnotte($organization, $admin, ['recurring' => true, 'duration' => 'flash_24h']);
    $first->ensureShareCode();
    $code = $first->share_code;

    addContribution($first, $admin, 5000, PaymentMethod::PayDunya);
    $first->update(['ends_at' => now()->subMinute()]);

    $url = "/api/v1/orgs/{$organization->id}/cagnottes/{$first->id}";
    $this->postJson($url.'/draw', ['reveal_after' => now()->addSecond()->toIso8601String()])->assertOk();
    $this->travel(2)->seconds();
    $this->postJson($url.'/draw/reveal')->assertOk()->assertJsonPath('data.edition', 1);

    $second = Cagnotte::where('series_id', $first->id)->firstOrFail();

    expect($second->edition)->toBe(2)
        ->and($second->title)->toBe($first->title)
        ->and($second->ticket_price)->toBe(500)
        ->and($second->recurring)->toBeTrue()
        ->and($second->ends_at->greaterThan(now()))->toBeTrue()
        // L'édition jouée n'est pas touchée : ses participants et son tirage restent en place.
        ->and($first->refresh()->drawn_at)->not->toBeNull();

    // Le lien partagé, resté sur la première édition, ouvre celle qui est en cours.
    $this->getJson("/api/v1/links/{$code}")
        ->assertOk()
        ->assertJsonPath('type', 'cagnotte')
        ->assertJsonPath('data.edition', 2)
        ->assertJsonPath('data.collected_amount', 0);

    // Révéler deux fois ne crée pas deux éditions.
    $this->postJson($url.'/draw/reveal')->assertUnprocessable();
    expect(Cagnotte::where('series_id', $first->id)->count())->toBe(1);
});

it('remplit une cagnotte à partir d’un modèle, sans écraser ce qui est saisi', function () {
    $organization = Organization::factory()->create();
    actingAsUser(memberOf($organization, Role::Admin));

    $template = CagnotteTemplate::create([
        'name' => 'Tombola du mois',
        'mode' => CagnotteMode::Prize,
        'duration' => 'mensuelle_30j',
        'ticket_price' => 1000,
        'winners_count' => 3,
        'prize_split' => [50, 30, 20],
        'recurring' => true,
    ]);

    $this->getJson('/api/v1/cagnotte-templates')
        ->assertOk()
        ->assertJsonPath('data.0.name', 'Tombola du mois')
        ->assertJsonPath('data.0.recurring', true);

    $id = $this->postJson("/api/v1/orgs/{$organization->id}/cagnottes", [
        'title' => 'Tombola de septembre',
        'template_id' => $template->id,
        // Ce qui est saisi l'emporte sur le modèle.
        'ticket_price' => 2000,
    ])->assertCreated()->json('data.id');

    expect(Cagnotte::findOrFail($id))
        ->ticket_price->toBe(2000)
        ->winners_count->toBe(3)
        ->recurring->toBeTrue()
        ->template_id->toBe($template->id)
        ->and(Cagnotte::findOrFail($id)->duration->value)->toBe('mensuelle_30j');
});

it('donne son espace personnel à un compte qui n’appartient à aucun groupement', function () {
    $user = actingAsUser(User::factory()->create(['name' => 'Awa Ouédraogo']));

    $this->getJson('/api/v1/orgs')
        ->assertOk()
        ->assertJsonPath('data.0.name', 'Espace de Awa Ouédraogo')
        ->assertJsonPath('data.0.role', 'owner');

    // Appelé deux fois, il n'en crée pas deux.
    $this->getJson('/api/v1/orgs')->assertJsonCount(1, 'data');
    expect($user->organizations()->first()->isPersonal())->toBeTrue();
});

it('retire les cagnottes à gagnants de l’annuaire quand l’interrupteur est refermé', function () {
    $organization = Organization::factory()->create();
    $admin = memberOf($organization, Role::Admin);
    publicCagnotte($organization, $admin);
    Cagnotte::factory()->for($organization)->create([
        'created_by' => $admin->id,
        'title' => 'Soutien à la famille',
        'visibility' => Visibility::Listed,
    ]);

    actingAsUser(User::factory()->create());

    // Ouvert : les deux cagnottes sont dans l'annuaire.
    expect($this->getJson('/api/v1/discover')->json('data.cagnottes'))->toHaveCount(2);

    config(['cagnottes.public_prize_pools' => false]);

    // Refermé : seule la cagnotte solidaire reste listée.
    $listed = $this->getJson('/api/v1/discover')->json('data.cagnottes');

    expect($listed)->toHaveCount(1)
        ->and($listed[0]['title'])->toBe('Soutien à la famille');
});
