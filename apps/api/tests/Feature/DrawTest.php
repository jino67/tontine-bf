<?php

use App\Enums\TontineType;

it("refuse le tirage pour une tontine qui n'est pas de type tirage_ordre", function () {
    ['owner' => $owner, 'tontine' => $tontine] = startedTontine();
    actingAsUser($owner);

    $this->postJson(tontineUrl($tontine, '/draw'))->assertUnprocessable();
});

it("publie l'empreinte sans la graine, puis révèle un ordre que chaque membre peut recalculer", function () {
    ['owner' => $owner, 'awa' => $awa, 'tontine' => $tontine] = startedTontine(TontineType::DrawOrder, ['awa' => 2]);

    actingAsUser($owner);
    $committed = $this->postJson(tontineUrl($tontine, '/draw'), ['reveal_after' => now()->addHours(2)->toIso8601String()])
        ->assertCreated()
        ->assertJsonPath('data.status', 'engage')
        ->assertJsonMissingPath('data.seed')
        ->json('data');

    expect($committed['slots'])->toHaveCount(3);
    $this->postJson(tontineUrl($tontine, '/draw'))->assertUnprocessable();

    // Même le propriétaire ne peut pas révéler avant la date annoncée.
    $this->postJson(tontineUrl($tontine, '/draw/reveal'))->assertUnprocessable();

    $this->travel(3)->hours();
    actingAsUser($awa);
    $revealed = $this->postJson(tontineUrl($tontine, '/draw/reveal'))->assertOk()->json('data');

    // Recalcul indépendant, sans passer par le code de l'application.
    $expectedOrder = collect($committed['slots'])
        ->sortBy(fn (string $slot) => hash('sha256', $revealed['seed'].'|'.$slot), SORT_STRING)
        ->values()
        ->all();

    expect(hash('sha256', $revealed['seed']))->toBe($committed['seed_hash'])
        ->and($revealed['order'])->toBe($expectedOrder)
        ->and($tontine->cycles()->orderBy('number')->pluck('beneficiary_member_id')->all())
        ->toBe(array_map(fn (string $slot) => (int) explode('#', $slot)[0], $expectedOrder));

    $this->postJson(tontineUrl($tontine, '/draw/reveal'))->assertUnprocessable();
});
