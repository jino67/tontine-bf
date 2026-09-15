<?php

use App\Models\OtpCode;

it('liste les cotisations du membre connecté, de la plus proche à la plus lointaine', function () {
    ['organization' => $organization, 'awa' => $awa, 'tontine' => $tontine] = startedTontine();
    ['tontine' => $foreignTontine] = startedTontine();

    actingAsUser($awa);
    $rows = $this->getJson('/api/v1/me/contributions')->assertOk()->assertJsonCount(2, 'data')->json('data');

    expect($rows[0]['cycle_number'])->toBe(1)
        ->and($rows[0]['due_on'])->toBe($tontine->starts_on->toDateString())
        ->and($rows[0]['tontine']['name'])->toBe($tontine->name)
        ->and($rows[0]['is_late'])->toBeFalse()
        ->and($rows[0]['is_beneficiary'])->toBeTrue()
        ->and($rows[1]['is_beneficiary'])->toBeFalse();

    $this->getJson("/api/v1/me/contributions?organization_id={$organization->id}")->assertJsonCount(2, 'data');
    $this->getJson("/api/v1/me/contributions?organization_id={$foreignTontine->organization_id}")->assertJsonCount(0, 'data');

    // Une semaine et un jour plus tard, la première échéance est dépassée sans paiement.
    $this->travel(8)->days();
    $this->getJson('/api/v1/me/contributions')->assertJsonPath('data.0.is_late', true);
});

it('expose la progression des cotisations et la prochaine échéance de chaque tontine', function () {
    ['organization' => $organization, 'treasurer' => $treasurer, 'awa' => $awa, 'tontine' => $tontine] = startedTontine();

    actingAsUser($treasurer);
    $this->putJson(contributionUrl(contributionOf($tontine, $awa)), ['amount_paid' => 5000, 'method' => 'especes'])->assertOk();

    $this->getJson("/api/v1/orgs/{$organization->id}/tontines")
        ->assertOk()
        ->assertJsonPath('data.0.members_count', 2)
        ->assertJsonPath('data.0.amount_due_total', 20000)
        ->assertJsonPath('data.0.amount_paid_total', 5000)
        ->assertJsonPath('data.0.next_due_on', $tontine->starts_on->toDateString());

    $this->getJson(tontineUrl($tontine))->assertJsonPath('data.amount_paid_total', 5000);
});

it('purge les codes OTP expirés depuis plus d\'un jour', function () {
    $old = OtpCode::create(['phone' => '+22670123456', 'code_hash' => str_repeat('a', 64), 'expires_at' => now()->subDays(2)]);
    $recent = OtpCode::create(['phone' => '+22670123456', 'code_hash' => str_repeat('b', 64), 'expires_at' => now()->addMinutes(5)]);

    $this->artisan('model:prune', ['--model' => OtpCode::class])->assertSuccessful();

    expect(OtpCode::find($old->id))->toBeNull()
        ->and(OtpCode::find($recent->id))->not->toBeNull();
});
