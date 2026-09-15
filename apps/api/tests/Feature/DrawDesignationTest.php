<?php

use App\Enums\TontineStatus;
use App\Enums\TontineType;

it('publie dès le lancement les tours attribués par le responsable et tire les autres au sort', function () {
    ['owner' => $owner, 'awa' => $awa, 'binta' => $binta, 'tontine' => $tontine] = startedTontine(TontineType::DrawOrder, ['awa' => 2]);
    $bintaMember = $tontine->members()->where('user_id', $binta->id)->value('id');

    actingAsUser($owner);
    $committed = $this->postJson(tontineUrl($tontine, '/draw'), [
        'reveal_after' => now()->addHour()->toIso8601String(),
        'designations' => [['cycle' => 1, 'member_id' => $bintaMember]],
    ])
        ->assertCreated()
        ->assertJsonPath('data.designations.0', ['cycle' => 1, 'slot' => "{$bintaMember}#1"])
        ->json('data');

    expect($committed['slots'])->toHaveCount(2)->not->toContain("{$bintaMember}#1");

    // Un simple membre voit l'attribution avant la révélation.
    actingAsUser($awa);
    $this->getJson(tontineUrl($tontine, '/draw'))
        ->assertOk()
        ->assertJsonPath('data.designations.0.cycle', 1)
        ->assertJsonMissingPath('data.seed');

    $this->travel(2)->hours();
    $revealed = $this->postJson(tontineUrl($tontine, '/draw/reveal'))->assertOk()->json('data');

    $drawn = collect($committed['slots'])
        ->sortBy(fn (string $slot) => hash('sha256', $revealed['seed'].'|'.$slot), SORT_STRING)
        ->values()
        ->all();

    expect($revealed['order'])->toBe(["{$bintaMember}#1", ...$drawn])
        ->and($tontine->cycles()->orderBy('number')->value('beneficiary_member_id'))->toBe($bintaMember);
});

it('refuse de désigner un membre plus souvent que son nombre de parts', function () {
    ['owner' => $owner, 'binta' => $binta, 'tontine' => $tontine] = startedTontine(TontineType::DrawOrder, ['awa' => 2]);
    $bintaMember = $tontine->members()->where('user_id', $binta->id)->value('id');
    actingAsUser($owner);

    $this->postJson(tontineUrl($tontine, '/draw'), [
        'designations' => [['cycle' => 1, 'member_id' => $bintaMember], ['cycle' => 2, 'member_id' => $bintaMember]],
    ])->assertUnprocessable();

    $this->postJson(tontineUrl($tontine, '/draw'), [
        'designations' => [['cycle' => 1, 'member_id' => $bintaMember], ['cycle' => 1, 'member_id' => $bintaMember]],
    ])->assertUnprocessable()->assertJsonValidationErrors('designations.1.cycle');

    expect($tontine->draw()->exists())->toBeFalse();
});

it('termine la tontine quand toutes les cotisations sont payées, et la rouvre si un paiement est annulé', function () {
    ['treasurer' => $treasurer, 'awa' => $awa, 'binta' => $binta, 'tontine' => $tontine] = startedTontine();
    actingAsUser($treasurer);

    foreach ([1, 2] as $cycle) {
        foreach ([$awa, $binta] as $member) {
            $this->putJson(contributionUrl(contributionOf($tontine, $member, $cycle)), ['amount_paid' => 5000, 'method' => 'especes'])
                ->assertOk();
        }
    }

    expect($tontine->refresh()->status)->toBe(TontineStatus::Completed);

    $this->putJson(contributionUrl(contributionOf($tontine, $binta, 2)), ['amount_paid' => 0])->assertOk();

    expect($tontine->refresh()->status)->toBe(TontineStatus::Active);
});
