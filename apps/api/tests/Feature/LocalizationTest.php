<?php

use App\Models\Organization;
use App\Models\User;

it('répond avec des messages de validation en français', function () {
    fakeOtpSender();

    $this->postJson('/api/v1/auth/otp/request', [])
        ->assertUnprocessable()
        ->assertJsonValidationErrors(['phone' => 'Le champ numéro de téléphone est obligatoire.']);

    actingAsUser(User::factory()->create());

    $this->postJson('/api/v1/orgs', ['name' => 'AB'])
        ->assertJsonValidationErrors(['name' => 'Le champ nom doit contenir au moins 3 caractères.']);
});

it('traduit aussi les messages personnalisés par règle', function () {
    ['treasurer' => $treasurer, 'awa' => $awa, 'tontine' => $tontine] = startedTontine();
    actingAsUser($treasurer);

    $this->putJson(contributionUrl(contributionOf($tontine, $awa)), ['amount_paid' => 5000])
        ->assertJsonValidationErrors(['method' => 'Indiquez le moyen de paiement.']);

    expect(Organization::count())->toBe(1);
});
