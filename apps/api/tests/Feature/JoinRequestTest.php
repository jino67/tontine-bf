<?php

use App\Enums\Role;
use App\Models\Cagnotte;
use App\Models\JoinRequest;
use App\Models\Organization;
use App\Models\Tontine;
use App\Models\User;

function openTontine(Organization $organization, int $creatorId, array $attributes = []): Tontine
{
    return Tontine::factory()->for($organization)->create([
        'created_by' => $creatorId,
        'name' => 'Tontine du marché',
        'amount' => 5000,
        'max_members' => 12,
        'visibility' => 'publique',
        'join_policy' => 'sur_demande',
        ...$attributes,
    ]);
}

it('laisse demander à rejoindre une tontine publique, puis le responsable approuve', function () {
    $organization = Organization::factory()->create(['visibility' => 'publique']);
    $admin = memberOf($organization, Role::Admin);
    $tontine = openTontine($organization, $admin->id);
    $binta = User::factory()->create(['name' => 'Binta']);

    actingAsUser($binta);
    $requestId = $this->postJson('/api/v1/join-requests', [
        'type' => 'tontine',
        'id' => $tontine->id,
        'message' => 'Je cotise chaque semaine au marché.',
    ])
        ->assertCreated()
        ->assertJsonPath('data.status', 'en_attente')
        ->json('data.id');

    // Le demandeur suit sa demande, et la fiche publique le lui rappelle.
    $this->getJson('/api/v1/join-requests')->assertOk()->assertJsonPath('data.0.id', $requestId);
    $this->getJson('/api/v1/links/'.$tontine->ensureShareCode())
        ->assertOk()
        ->assertJsonPath('data.viewer.is_member', false)
        ->assertJsonPath('data.viewer.has_pending_request', true);

    actingAsUser($admin);
    $this->getJson("/api/v1/orgs/{$organization->id}/join-requests")
        ->assertOk()
        ->assertJsonPath('data.0.user.name', 'Binta')
        ->assertJsonPath('data.0.tontine.name', 'Tontine du marché');

    $this->postJson("/api/v1/orgs/{$organization->id}/join-requests/{$requestId}/approve")
        ->assertOk()
        ->assertJsonPath('data.status', 'approuvee');

    expect($tontine->fresh()->hasMember($binta->id))->toBeTrue()
        ->and($organization->memberships()->where('user_id', $binta->id)->exists())->toBeTrue();

    // Une deuxième demande n'a plus lieu d'être.
    actingAsUser($binta);
    $this->postJson('/api/v1/join-requests', ['type' => 'tontine', 'id' => $tontine->id])
        ->assertUnprocessable()
        ->assertJsonPath('message', 'Vous en faites déjà partie.');
});

it('fait entrer directement quand l’adhésion est libre', function () {
    $organization = Organization::factory()->create(['visibility' => 'publique', 'join_policy' => 'libre']);
    memberOf($organization, Role::Owner);
    $awa = actingAsUser(User::factory()->create());

    $this->postJson('/api/v1/join-requests', ['type' => 'organisation', 'id' => $organization->id])
        ->assertCreated()
        ->assertJsonPath('status', 'approuvee');

    expect($organization->memberships()->where('user_id', $awa->id)->exists())->toBeTrue();
});

it('refuse une demande, puis ferme la porte après trois refus', function () {
    $organization = Organization::factory()->create(['visibility' => 'publique']);
    $admin = memberOf($organization, Role::Admin);
    $tontine = openTontine($organization, $admin->id);
    $binta = User::factory()->create();

    foreach (range(1, 3) as $attempt) {
        actingAsUser($binta);
        $id = $this->postJson('/api/v1/join-requests', ['type' => 'tontine', 'id' => $tontine->id])
            ->assertCreated()
            ->json('data.id');

        actingAsUser($admin);
        $this->postJson("/api/v1/orgs/{$organization->id}/join-requests/{$id}/reject", ['reason' => 'Groupe complet'])
            ->assertOk()
            ->assertJsonPath('data.status', 'refusee')
            ->assertJsonPath('data.decision_reason', 'Groupe complet');
    }

    actingAsUser($binta);
    $this->postJson('/api/v1/join-requests', ['type' => 'tontine', 'id' => $tontine->id])
        ->assertUnprocessable()
        ->assertJsonPath('message', 'Votre demande a déjà été refusée trois fois. Réessayez dans un mois.');
});

it('refuse les demandes sur une tontine privée, démarrée ou sur invitation', function () {
    $organization = Organization::factory()->create(['visibility' => 'publique']);
    $admin = memberOf($organization, Role::Admin);
    $privee = openTontine($organization, $admin->id, ['visibility' => 'privee']);
    $demarree = openTontine($organization, $admin->id, ['started_at' => now(), 'status' => 'active']);
    $surInvitation = openTontine($organization, $admin->id, ['join_policy' => 'fermee']);

    actingAsUser(User::factory()->create());

    $this->postJson('/api/v1/join-requests', ['type' => 'tontine', 'id' => $privee->id])->assertNotFound();
    $this->postJson('/api/v1/join-requests', ['type' => 'tontine', 'id' => $demarree->id])
        ->assertUnprocessable()
        ->assertJsonPath('message', 'Les inscriptions sont fermées depuis le démarrage.');
    $this->postJson('/api/v1/join-requests', ['type' => 'tontine', 'id' => $surInvitation->id])
        ->assertUnprocessable()
        ->assertJsonPath('message', 'Cette page se rejoint uniquement sur invitation.');
});

it('laisse le demandeur retirer sa demande, et la réserve aux responsables', function () {
    $organization = Organization::factory()->create(['visibility' => 'publique']);
    $admin = memberOf($organization, Role::Admin);
    $tontine = openTontine($organization, $admin->id);
    $binta = actingAsUser(User::factory()->create());

    $id = $this->postJson('/api/v1/join-requests', ['type' => 'tontine', 'id' => $tontine->id])->json('data.id');

    $this->deleteJson("/api/v1/join-requests/{$id}")->assertOk()->assertJsonPath('data.status', 'retiree');

    // Un membre simple de l'organisation ne voit pas la file des demandes.
    actingAsUser(memberOf($organization));
    $this->getJson("/api/v1/orgs/{$organization->id}/join-requests")->assertForbidden();

    // Et personne ne traite la demande d'un autre.
    actingAsUser($binta);
    $this->postJson("/api/v1/orgs/{$organization->id}/join-requests/{$id}/approve")->assertForbidden();
});

it('liste dans l’annuaire les tontines et cagnottes publiques, sans donnée personnelle', function () {
    $organization = Organization::factory()->create(['visibility' => 'publique', 'name' => 'Groupement Wend Panga']);
    $admin = memberOf($organization, Role::Admin);
    $awa = memberOf($organization);
    $publique = openTontine($organization, $admin->id);
    $publique->addMember($awa, 1, 1);
    openTontine($organization, $admin->id, ['name' => 'Tontine privée', 'visibility' => 'privee']);
    openTontine($organization, $admin->id, ['name' => 'Tontine démarrée', 'started_at' => now(), 'status' => 'active']);
    Cagnotte::factory()->for($organization)->create([
        'created_by' => $admin->id,
        'title' => 'Cagnotte du vendredi',
        'visibility' => 'publique',
        'ends_at' => now()->addDay(),
    ]);

    actingAsUser(User::factory()->create());
    $response = $this->getJson('/api/v1/discover')
        ->assertOk()
        ->assertJsonCount(1, 'data.tontines')
        ->assertJsonCount(1, 'data.cagnottes')
        ->assertJsonPath('data.tontines.0.name', 'Tontine du marché')
        ->assertJsonPath('data.tontines.0.organization', 'Groupement Wend Panga')
        ->assertJsonPath('data.cagnottes.0.title', 'Cagnotte du vendredi');

    expect($response->content())->not->toContain($awa->phone);

    // Le filtre par nom et par montant maximum.
    $this->getJson('/api/v1/discover?q=marche')->assertOk()->assertJsonCount(0, 'data.tontines');
    $this->getJson('/api/v1/discover?q=march')->assertOk()->assertJsonCount(1, 'data.tontines');
    $this->getJson('/api/v1/discover?max_amount=1000')->assertOk()->assertJsonCount(0, 'data.tontines');
});

it('retire une fiche de l’annuaire après trois signalements', function () {
    $organization = Organization::factory()->create(['visibility' => 'publique']);
    $admin = memberOf($organization, Role::Admin);
    $tontine = openTontine($organization, $admin->id);

    foreach (range(1, 2) as $attempt) {
        actingAsUser(User::factory()->create());
        $this->postJson('/api/v1/reports', ['type' => 'tontine', 'id' => $tontine->id, 'reason' => 'arnaque'])
            ->assertCreated()
            ->assertJsonPath('hidden', false);
    }

    // Le même signalant ne compte qu'une fois.
    $this->postJson('/api/v1/reports', ['type' => 'tontine', 'id' => $tontine->id, 'reason' => 'arnaque'])
        ->assertCreated()
        ->assertJsonPath('hidden', false);

    actingAsUser(User::factory()->create());
    $this->postJson('/api/v1/reports', ['type' => 'tontine', 'id' => $tontine->id, 'reason' => 'montants_irrealistes'])
        ->assertCreated()
        ->assertJsonPath('hidden', true);

    expect($tontine->fresh()->hidden_at)->not->toBeNull();

    $this->getJson('/api/v1/discover')->assertOk()->assertJsonCount(0, 'data.tontines');
    $this->getJson('/api/v1/links/'.$tontine->ensureShareCode())->assertNotFound();
    $this->postJson('/api/v1/join-requests', ['type' => 'tontine', 'id' => $tontine->id])->assertNotFound();
});

it('garde la trace de qui a tranché', function () {
    $organization = Organization::factory()->create(['visibility' => 'publique']);
    $admin = memberOf($organization, Role::Admin);
    $tontine = openTontine($organization, $admin->id);
    $binta = actingAsUser(User::factory()->create());

    $id = $this->postJson('/api/v1/join-requests', ['type' => 'tontine', 'id' => $tontine->id])->json('data.id');

    actingAsUser($admin);
    $this->postJson("/api/v1/orgs/{$organization->id}/join-requests/{$id}/approve")->assertOk();

    $joinRequest = JoinRequest::find($id);

    expect($joinRequest->decided_by)->toBe($admin->id)
        ->and($joinRequest->decided_at)->not->toBeNull()
        ->and($joinRequest->user_id)->toBe($binta->id);

    // Une demande déjà traitée ne se retraite pas.
    $this->postJson("/api/v1/orgs/{$organization->id}/join-requests/{$id}/reject")
        ->assertUnprocessable()
        ->assertJsonPath('message', 'Cette demande a déjà été traitée.');
});
