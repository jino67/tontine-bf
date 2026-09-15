<?php

use App\Enums\CagnotteDuration;
use App\Enums\CagnotteMode;
use App\Enums\Role;
use App\Models\Cagnotte;
use App\Models\Organization;
use App\Models\User;
use App\Services\CagnottePrizeDraw;

function prizeUrl(Cagnotte $cagnotte, string $path = ''): string
{
    return "/api/v1/orgs/{$cagnotte->organization_id}/cagnottes/{$cagnotte->id}{$path}";
}

function prizeCagnotte(Organization $organization, User $creator, array $attributes = []): Cagnotte
{
    return Cagnotte::factory()->for($organization)->create([
        'created_by' => $creator->id,
        'mode' => CagnotteMode::Prize,
        'ticket_price' => 250,
        'min_amount' => 250,
        'winners_count' => 3,
        'prize_split' => [50, 30, 20],
        'beneficiary_name' => null,
        ...$attributes,
    ]);
}

it('crée une cagnotte à gagnants avec la répartition par défaut et des rangs attribués visibles de tous', function () {
    $organization = Organization::factory()->create();
    $admin = actingAsUser(memberOf($organization, Role::Admin));
    $awa = memberOf($organization);

    $id = $this->postJson("/api/v1/orgs/{$organization->id}/cagnottes", [
        'title' => 'Cagnotte Flash du vendredi',
        'mode' => 'gagnants',
        'duration' => 'flash_24h',
        'ticket_price' => 250,
        'winners_count' => 3,
        'fee_percent' => 10,
        'designations' => [['rank' => 1, 'user_id' => $admin->id]],
    ])
        ->assertCreated()
        ->assertJsonPath('data.mode', 'gagnants')
        ->assertJsonPath('data.min_amount', 250)
        ->assertJsonPath('data.beneficiary', null)
        ->assertJsonPath('data.prizes.0.percent', 50)
        ->assertJsonPath('data.prizes.0.designated_user.id', $admin->id)
        ->assertJsonPath('data.prizes.2.designated_user', null)
        ->json('data.id');

    actingAsUser($awa);
    $this->getJson("/api/v1/orgs/{$organization->id}/cagnottes/{$id}")
        ->assertOk()
        ->assertJsonPath('data.prizes.0.designated_user.name', $admin->name);
});

it('refuse une répartition incohérente ou un rang attribué au-delà du nombre de gagnants', function () {
    $organization = Organization::factory()->create();
    $admin = actingAsUser(memberOf($organization, Role::Admin));
    $payload = ['title' => 'Cagnotte', 'mode' => 'gagnants', 'duration' => 'hebdo_7j', 'ticket_price' => 500, 'winners_count' => 2];

    $this->postJson("/api/v1/orgs/{$organization->id}/cagnottes", [...$payload, 'prize_split' => [70, 20]])
        ->assertUnprocessable()
        ->assertJsonValidationErrors('prize_split');

    $this->postJson("/api/v1/orgs/{$organization->id}/cagnottes", [...$payload, 'designations' => [['rank' => 3, 'user_id' => $admin->id]]])
        ->assertUnprocessable()
        ->assertJsonValidationErrors('designations.0.rank');
});

it('distribue tout le pot quand il y a moins de participants que de rangs', function () {
    $amounts = CagnottePrizeDraw::awardedAmounts(1575, [50, 30, 20], [1, 3]);

    expect(array_keys($amounts))->toBe([1, 3])
        ->and(array_sum($amounts))->toBe(1575)
        ->and(CagnottePrizeDraw::awardedAmounts(1575, [50, 30, 20], [1, 2, 3]))->toBe([1 => 788, 2 => 472, 3 => 315]);
});

it('verrouille les rangs attribués dès la première participation', function () {
    $organization = Organization::factory()->create();
    $admin = actingAsUser(memberOf($organization, Role::Admin));
    $awa = memberOf($organization);
    $cagnotte = prizeCagnotte($organization, $admin, ['winners_count' => 2, 'prize_split' => [60, 40]]);

    $this->putJson(prizeUrl($cagnotte, '/designations'), ['designations' => [['rank' => 2, 'user_id' => $awa->id]]])
        ->assertOk()
        ->assertJsonPath('data.prizes.1.designated_user.id', $awa->id);

    $this->postJson(prizeUrl($cagnotte, '/contributions'), ['user_id' => $awa->id, 'amount' => 1100, 'method' => 'especes'])
        ->assertCreated()
        ->assertJsonPath('data.tickets', 4);

    $this->putJson(prizeUrl($cagnotte, '/designations'), ['designations' => []])->assertUnprocessable();
});

it('tire les gagnants de façon vérifiable après la clôture, en respectant les rangs attribués, puis trace la remise des gains', function () {
    $organization = Organization::factory()->create();
    $admin = memberOf($organization, Role::Admin);
    [$awa, $binta, $cheick] = [memberOf($organization), memberOf($organization), memberOf($organization)];
    $cagnotte = prizeCagnotte($organization, $admin, [
        'duration' => CagnotteDuration::Flash,
        'ends_at' => now()->addDay(),
        'fee_percent' => 10,
        'designations' => [['rank' => 1, 'user_id' => $admin->id]],
    ]);

    actingAsUser($admin);
    foreach ([[$awa, 1000], [$binta, 500], [$cheick, 250]] as [$member, $amount]) {
        $this->postJson(prizeUrl($cagnotte, '/contributions'), ['user_id' => $member->id, 'amount' => $amount, 'method' => 'especes'])
            ->assertCreated();
    }

    $this->postJson(prizeUrl($cagnotte, '/draw'))->assertUnprocessable();

    $this->travel(25)->hours();
    $this->postJson(prizeUrl($cagnotte, '/handover'), ['amount' => 100, 'method' => 'especes'])->assertUnprocessable();

    $draw = $this->postJson(prizeUrl($cagnotte, '/draw'), ['reveal_after' => now()->addHour()->toIso8601String()])
        ->assertOk()
        ->assertJsonPath('data.tickets_count', 7)
        ->assertJsonPath('data.draw.seed', null)
        ->json('data.draw');

    expect($draw['tickets'])->toHaveCount(7);

    actingAsUser($binta);
    $this->postJson(prizeUrl($cagnotte, '/draw/reveal'))->assertUnprocessable();

    $this->travel(2)->hours();
    $data = $this->postJson(prizeUrl($cagnotte, '/draw/reveal'))
        ->assertOk()
        ->assertJsonPath('data.status', 'tiree')
        ->json('data');

    // Recalcul indépendant, sans passer par le code de l'application.
    $seed = $data['draw']['seed'];
    $userOf = fn (string $ticket) => (int) substr(explode('#', $ticket)[0], 1);
    $drawnUsers = collect($draw['tickets'])
        ->reject(fn (string $ticket) => $userOf($ticket) === $admin->id)
        ->sortBy(fn (string $ticket) => hash('sha256', $seed.'|'.$ticket), SORT_STRING)
        ->map($userOf)
        ->unique()
        ->values()
        ->all();

    $winners = collect($data['winners']);
    expect(hash('sha256', $seed))->toBe($draw['seed_hash'])
        ->and($winners->pluck('user.id')->all())->toBe([$admin->id, $drawnUsers[0], $drawnUsers[1]])
        ->and($winners->pluck('designated')->all())->toBe([true, false, false])
        ->and($winners->pluck('prize_amount')->all())->toBe([788, 472, 315]);

    $second = $winners->firstWhere('rank', 2);

    actingAsUser($admin);
    $this->postJson(prizeUrl($cagnotte, "/winners/{$second['id']}/payout"), ['method' => 'orange_money', 'reference' => 'OM-GAIN-2'])
        ->assertOk();
    $this->postJson(prizeUrl($cagnotte, "/winners/{$second['id']}/confirm"))->assertForbidden();

    actingAsUser(User::find($second['user']['id']));
    $this->postJson(prizeUrl($cagnotte, "/winners/{$second['id']}/confirm"))
        ->assertOk()
        ->assertJsonPath('data.winners.1.confirmed_at', fn ($value) => $value !== null);
});
