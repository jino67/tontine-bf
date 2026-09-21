<?php

use App\Enums\CagnotteMode;
use App\Enums\FeeOperation;
use App\Enums\PaymentMethod;
use App\Enums\Role;
use App\Models\Cagnotte;
use App\Models\FeeCharge;
use App\Models\FeeRule;
use App\Models\Organization;
use App\Models\User;

function addContribution(Cagnotte $cagnotte, User $user, int $amount, PaymentMethod $method): void
{
    $cagnotte->contributions()->create([
        'organization_id' => $cagnotte->organization_id,
        'user_id' => $user->id,
        'amount' => $amount,
        'tickets' => $cagnotte->ticketsFor($amount),
        'method' => $method,
        'paid_at' => now(),
        'recorded_by' => $user->id,
        'confirmed_at' => now(),
    ]);
}

it('publie la grille des frais sans demander de compte', function () {
    $operations = $this->getJson('/api/v1/fees')->assertOk()->json('data.operations');

    $online = collect($operations)->firstWhere('operation', 'cotisation_en_ligne');
    $cash = collect($operations)->firstWhere('operation', 'cotisation_especes');

    expect($online['rate_bp'])->toBe(325)
        ->and($online['payer'])->toBe('payeur')
        ->and($online['rate_label'])->toBe('3,25 %')
        ->and($cash['rate_label'])->toBe('gratuit')
        ->and(collect($operations)->firstWhere('operation', 'cagnotte_gagnants')['rate_bp'])->toBe(500);
});

it('arrondit les frais au multiple de 5 FCFA supérieur', function () {
    actingAsUser(User::factory()->create());

    // 3,25 % de 5 000 font 162,50 : le membre paie 165 de frais, et 5 165 en tout.
    $this->postJson('/api/v1/fees/simulate', ['operation' => 'cotisation_en_ligne', 'amount' => 5000])
        ->assertOk()
        ->assertJsonPath('data.fee_amount', 165)
        ->assertJsonPath('data.total_amount', 5165)
        ->assertJsonPath('data.net_amount', 5000)
        ->assertJsonPath('data.summary', 'Vous payez 5 165 FCFA : 5 000 FCFA et 165 FCFA de frais de service.');

    $this->postJson('/api/v1/fees/simulate', ['operation' => 'cotisation_en_ligne', 'amount' => 1000])
        ->assertJsonPath('data.fee_amount', 35);
});

it('tient le minimum et le plafond de chaque règle', function () {
    actingAsUser(User::factory()->create());

    // Dépôt : 3 % avec un minimum de 100 FCFA.
    $this->postJson('/api/v1/fees/simulate', ['operation' => 'depot_portefeuille', 'amount' => 1000])
        ->assertJsonPath('data.fee_amount', 100);

    // Cotisation réglée depuis le solde : 1 %, plafonné à 500 FCFA.
    $this->postJson('/api/v1/fees/simulate', ['operation' => 'cotisation_solde', 'amount' => 200000])
        ->assertJsonPath('data.fee_amount', 500);

    // Le transfert entre membres reste gratuit.
    $this->postJson('/api/v1/fees/simulate', ['operation' => 'transfert_interne', 'amount' => 50000])
        ->assertJsonPath('data.fee_amount', 0)
        ->assertJsonPath('data.summary', 'Aucun frais sur cette opération.');
});

it('applique la règle propre à une organisation avant la règle générale', function () {
    $organization = Organization::factory()->create();
    actingAsUser(memberOf($organization, Role::Owner));

    FeeRule::create([
        'operation' => FeeOperation::ContributionOnline,
        'organization_id' => $organization->id,
        'label' => 'Tarif du plan payant',
        'rate_bp' => 200,
        'starts_at' => now()->subDay(),
    ]);

    $this->postJson('/api/v1/fees/simulate', [
        'operation' => 'cotisation_en_ligne',
        'amount' => 5000,
        'organization_id' => $organization->id,
    ])->assertJsonPath('data.fee_amount', 100);

    // Un membre d'une autre organisation ne profite pas de ce tarif.
    actingAsUser(User::factory()->create());
    $this->postJson('/api/v1/fees/simulate', [
        'operation' => 'cotisation_en_ligne',
        'amount' => 5000,
        'organization_id' => $organization->id,
    ])->assertJsonPath('data.fee_amount', 165);
});

it('ne prélève que sur l’argent réellement passé par l’application', function () {
    $organization = Organization::factory()->create();
    $admin = actingAsUser(memberOf($organization, Role::Admin));

    $id = $this->postJson("/api/v1/orgs/{$organization->id}/cagnottes", [
        'title' => 'Cagnotte du vendredi',
        'mode' => 'gagnants',
        'duration' => 'flash_24h',
        'ticket_price' => 250,
        'winners_count' => 1,
        'fee_percent' => 10,
    ])->assertCreated()->json('data.id');

    $cagnotte = Cagnotte::findOrFail($id);
    expect($cagnotte->platform_fee_bp)->toBe(500);

    addContribution($cagnotte, $admin, 10000, PaymentMethod::PayDunya);
    addContribution($cagnotte, memberOf($organization), 5000, PaymentMethod::Cash);

    $cagnotte = Cagnotte::whereKey($id)->withTotals()->firstOrFail();

    // 5 % des 10 000 reçus en ligne, et rien sur les 5 000 remis en espèces au trésorier.
    expect($cagnotte->collectedAmount())->toBe(15000)
        ->and($cagnotte->onlineCollected())->toBe(10000)
        ->and($cagnotte->platformFee())->toBe(500)
        // Le pot retire la part de la plateforme, puis la commission de l'organisation.
        ->and($cagnotte->pot())->toBe(13000);
});

it('inscrit la part de la plateforme au moment du tirage, une seule fois', function () {
    $organization = Organization::factory()->create();
    $admin = actingAsUser(memberOf($organization, Role::Admin));

    $id = $this->postJson("/api/v1/orgs/{$organization->id}/cagnottes", [
        'title' => 'Cagnotte Flash',
        'mode' => 'gagnants',
        'duration' => 'flash_24h',
        'ticket_price' => 250,
        'winners_count' => 1,
    ])->assertCreated()->json('data.id');

    $cagnotte = Cagnotte::findOrFail($id);
    addContribution($cagnotte, $admin, 20000, PaymentMethod::PayDunya);
    $cagnotte->update(['ends_at' => now()->subMinute()]);

    $url = "/api/v1/orgs/{$organization->id}/cagnottes/{$id}";
    $this->postJson($url.'/draw', ['reveal_after' => now()->addSecond()->toIso8601String()])->assertOk();
    $this->travel(2)->seconds();
    $this->postJson($url.'/draw/reveal')
        ->assertOk()
        ->assertJsonPath('data.platform_fee_amount', 1000)
        ->assertJsonPath('data.pot_amount', 19000)
        ->assertJsonPath('data.winners.0.prize_amount', 19000);

    $charges = FeeCharge::where('operation', FeeOperation::PrizePool)->get();

    expect($charges)->toHaveCount(1)
        ->and($charges->first()->fee_amount)->toBe(1000)
        ->and($charges->first()->base_amount)->toBe(20000)
        ->and($charges->first()->chargeable_id)->toBe($cagnotte->id);
});

it('ne laisse pas remettre au bénéficiaire plus que le pot', function () {
    $organization = Organization::factory()->create();
    $admin = actingAsUser(memberOf($organization, Role::Admin));
    $beneficiary = memberOf($organization);

    $id = $this->postJson("/api/v1/orgs/{$organization->id}/cagnottes", [
        'title' => 'Soutien à Awa',
        'mode' => 'solidaire',
        'duration' => 'flash_24h',
        'beneficiary_user_id' => $beneficiary->id,
    ])->assertCreated()->json('data.id');

    $cagnotte = Cagnotte::findOrFail($id);
    expect($cagnotte->platform_fee_bp)->toBe(200)
        ->and($cagnotte->mode)->toBe(CagnotteMode::Solidarity);

    addContribution($cagnotte, $admin, 50000, PaymentMethod::PayDunya);
    $cagnotte->update(['ends_at' => now()->subMinute()]);

    $url = "/api/v1/orgs/{$organization->id}/cagnottes/{$id}/handover";
    // 2 % de 50 000 : 1 000 de frais, donc 49 000 remis au plus.
    $this->postJson($url, ['amount' => 50000, 'method' => 'especes'])->assertUnprocessable();
    $this->postJson($url, ['amount' => 49000, 'method' => 'especes'])->assertOk();

    expect(FeeCharge::where('operation', FeeOperation::SolidarityPool)->sum('fee_amount'))->toBe(1000);
});
