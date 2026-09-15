<?php

it("permet au trésorier d'enregistrer un paiement puis au membre de le confirmer", function () {
    ['treasurer' => $treasurer, 'awa' => $awa, 'tontine' => $tontine] = startedTontine();
    $contribution = contributionOf($tontine, $awa);

    actingAsUser($treasurer);
    $this->putJson(contributionUrl($contribution), [
        'amount_paid' => 5000,
        'method' => 'orange_money',
        'reference' => 'PP250915.1432.A12345',
    ])
        ->assertOk()
        ->assertJsonPath('data.status', 'enregistree')
        ->assertJsonPath('data.method', 'orange_money');

    actingAsUser($awa);
    $this->postJson(contributionUrl($contribution).'/confirm')
        ->assertOk()
        ->assertJsonPath('data.status', 'confirmee');

    // Une fois confirmée, la cotisation ne peut plus être modifiée.
    actingAsUser($treasurer);
    $this->putJson(contributionUrl($contribution), ['amount_paid' => 0])->assertUnprocessable();

    expect($contribution->refresh()->amount_paid)->toBe(5000);
});

it("réserve l'enregistrement au trésorier et la confirmation au membre concerné", function () {
    ['treasurer' => $treasurer, 'awa' => $awa, 'binta' => $binta, 'tontine' => $tontine] = startedTontine();
    $contribution = contributionOf($tontine, $awa);

    actingAsUser($binta);
    $this->putJson(contributionUrl($contribution), ['amount_paid' => 5000, 'method' => 'especes'])->assertForbidden();

    actingAsUser($awa);
    $this->postJson(contributionUrl($contribution).'/confirm')->assertUnprocessable();

    actingAsUser($treasurer);
    $this->putJson(contributionUrl($contribution), ['amount_paid' => 5000, 'method' => 'especes'])->assertOk();

    actingAsUser($binta);
    $this->postJson(contributionUrl($contribution).'/confirm')->assertForbidden();
});

it('refuse un montant supérieur à la cotisation due ou sans moyen de paiement', function () {
    ['treasurer' => $treasurer, 'awa' => $awa, 'tontine' => $tontine] = startedTontine();
    $contribution = contributionOf($tontine, $awa);

    actingAsUser($treasurer);

    $this->putJson(contributionUrl($contribution), ['amount_paid' => 6000, 'method' => 'especes'])
        ->assertUnprocessable()
        ->assertJsonValidationErrors('amount_paid');

    $this->putJson(contributionUrl($contribution), ['amount_paid' => 5000])
        ->assertUnprocessable()
        ->assertJsonValidationErrors('method');
});

it('marque le cycle comme réglé quand toutes les cotisations sont payées', function () {
    ['treasurer' => $treasurer, 'awa' => $awa, 'binta' => $binta, 'tontine' => $tontine] = startedTontine();

    actingAsUser($treasurer);

    foreach ([$awa, $binta] as $member) {
        $this->putJson(contributionUrl(contributionOf($tontine, $member)), ['amount_paid' => 5000, 'method' => 'especes'])
            ->assertOk();
    }

    $cycle = contributionOf($tontine, $awa)->cycle;

    $this->getJson(tontineUrl($tontine, "/cycles/{$cycle->id}"))
        ->assertOk()
        ->assertJsonPath('data.status', 'regle')
        ->assertJsonPath('data.amount_paid_total', 10000)
        ->assertJsonCount(2, 'data.contributions');
});
