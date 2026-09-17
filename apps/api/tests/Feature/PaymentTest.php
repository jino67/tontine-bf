<?php

use App\Enums\CagnotteMode;
use App\Enums\PaymentMethod;
use App\Enums\Role;
use App\Models\Cagnotte;
use App\Models\CagnotteWinner;
use App\Models\Organization;
use Illuminate\Support\Facades\Http;

function fakePayDunyaConfig(bool $payouts = false): void
{
    config(['services.paydunya' => [
        'mode' => 'test',
        'master_key' => 'cle-principale',
        'public_key' => 'test_public',
        'private_key' => 'test_private',
        'token' => 'jeton',
        'store_name' => 'Tontine BF',
        'payouts_enabled' => $payouts,
    ]]);
}

function invoiceResponse(string $token): array
{
    return ['response_code' => '00', 'response_text' => "https://paydunya.com/sandbox-checkout/invoice/{$token}", 'token' => $token];
}

function confirmResponse(string $token, string $status, int|string $total): array
{
    return [
        'response_code' => '00',
        'status' => $status,
        'invoice' => ['token' => $token, 'total_amount' => $total],
        'receipt_url' => "https://paydunya.com/receipt/{$token}",
    ];
}

it('laisse un membre payer sa cotisation en ligne et la confirme dès que PayDunya valide', function () {
    fakePayDunyaConfig();
    ['awa' => $awa, 'binta' => $binta, 'tontine' => $tontine] = startedTontine();
    $contribution = contributionOf($tontine, $awa);

    Http::fake([
        '*/sandbox-api/v1/checkout-invoice/create' => Http::response(invoiceResponse('test_awa')),
        '*/sandbox-api/v1/checkout-invoice/confirm/test_awa' => Http::sequence()
            ->push(confirmResponse('test_awa', 'pending', 5000))
            ->push(confirmResponse('test_awa', 'completed', '5000')),
    ]);

    actingAsUser($binta);
    $this->postJson(contributionUrl($contribution).'/pay')->assertForbidden();

    actingAsUser($awa);
    $paymentId = $this->postJson(contributionUrl($contribution).'/pay')
        ->assertCreated()
        ->assertJsonPath('data.amount', 5000)
        ->assertJsonPath('data.purpose', 'cotisation')
        ->assertJsonPath('data.checkout_url', 'https://paydunya.com/sandbox-checkout/invoice/test_awa')
        ->json('data.id');

    Http::assertSent(fn ($request) => str_ends_with($request->url(), 'checkout-invoice/create')
        && $request->hasHeader('PAYDUNYA-MASTER-KEY', 'cle-principale')
        && $request['invoice']['total_amount'] === 5000
        && $request['custom_data']['payment_id'] === $paymentId
        && str_ends_with($request['actions']['callback_url'], '/api/v1/payments/paydunya/ipn'));

    $paymentUrl = "/api/v1/orgs/{$tontine->organization_id}/payments/{$paymentId}";
    $this->getJson($paymentUrl)->assertOk()->assertJsonPath('data.status', 'en_attente');

    // Une notification sans la bonne signature est rejetée et ne change rien.
    $this->post('/api/v1/payments/paydunya/ipn', ['data' => ['hash' => 'faux', 'status' => 'completed', 'invoice' => ['token' => 'test_awa']]])
        ->assertForbidden();
    expect($contribution->refresh()->amount_paid)->toBe(0);

    // Notification authentique : le statut est relu auprès de PayDunya, puis appliqué une seule fois.
    $ipn = ['data' => ['hash' => hash('sha512', 'cle-principale'), 'status' => 'completed', 'invoice' => ['token' => 'test_awa']]];
    $this->post('/api/v1/payments/paydunya/ipn', $ipn)->assertOk();
    $this->post('/api/v1/payments/paydunya/ipn', $ipn)->assertOk();

    expect($contribution->refresh())
        ->amount_paid->toBe(5000)
        ->method->toBe(PaymentMethod::PayDunya)
        ->reference->toBe('test_awa')
        ->confirmed_at->not->toBeNull();

    $this->getJson($paymentUrl)
        ->assertJsonPath('data.status', 'payee')
        ->assertJsonPath('data.applied', true)
        ->assertJsonPath('data.checkout_url', null);

    $this->postJson(contributionUrl($contribution).'/pay')->assertUnprocessable();
});

it('crée la participation et ses tickets quand un paiement de cagnotte aboutit, et rien sinon', function () {
    fakePayDunyaConfig();
    $organization = Organization::factory()->create();
    $admin = memberOf($organization, Role::Admin);
    $awa = memberOf($organization);
    $cagnotte = Cagnotte::factory()->for($organization)->create([
        'created_by' => $admin->id,
        'mode' => CagnotteMode::Prize,
        'ticket_price' => 250,
        'min_amount' => 250,
        'winners_count' => 1,
        'prize_split' => [100],
        'beneficiary_name' => null,
    ]);
    $base = "/api/v1/orgs/{$organization->id}";

    Http::fake([
        '*/checkout-invoice/create' => Http::sequence()
            ->push(invoiceResponse('tok_ok'))
            ->push(invoiceResponse('tok_montant'))
            ->push(invoiceResponse('tok_annule')),
        '*/checkout-invoice/confirm/tok_ok' => Http::response(confirmResponse('tok_ok', 'completed', 1000)),
        '*/checkout-invoice/confirm/tok_montant' => Http::response(confirmResponse('tok_montant', 'completed', 900)),
        '*/checkout-invoice/confirm/tok_annule' => Http::response(confirmResponse('tok_annule', 'cancelled', 500)),
    ]);

    actingAsUser($awa);
    $this->postJson("{$base}/cagnottes/{$cagnotte->id}/pay", ['amount' => 200])->assertJsonValidationErrors('amount');

    $ok = $this->postJson("{$base}/cagnottes/{$cagnotte->id}/pay", ['amount' => 1000])->assertCreated()->json('data.id');
    $wrongAmount = $this->postJson("{$base}/cagnottes/{$cagnotte->id}/pay", ['amount' => 1000])->json('data.id');
    $cancelled = $this->postJson("{$base}/cagnottes/{$cagnotte->id}/pay", ['amount' => 500])->json('data.id');

    $this->getJson("{$base}/payments/{$ok}")->assertJsonPath('data.status', 'payee')->assertJsonPath('data.applied', true);
    $this->getJson("{$base}/payments/{$wrongAmount}")->assertJsonPath('data.status', 'echouee');
    $this->getJson("{$base}/payments/{$cancelled}")->assertJsonPath('data.status', 'annulee');

    expect($cagnotte->contributions()->get())->toHaveCount(1)
        ->and($cagnotte->contributions()->first())
        ->tickets->toBe(4)
        ->method->toBe(PaymentMethod::PayDunya)
        ->confirmed_at->not->toBeNull();

    actingAsUser(memberOf($organization));
    $this->getJson("{$base}/payments/{$ok}")->assertForbidden();
});

it('n’envoie un gain par PayDunya que si les remises sont activées, puis le marque remis au succès', function () {
    fakePayDunyaConfig();
    $organization = Organization::factory()->create();
    $admin = memberOf($organization, Role::Admin);
    $awa = memberOf($organization);
    $cagnotte = Cagnotte::factory()->for($organization)->create([
        'created_by' => $admin->id,
        'mode' => CagnotteMode::Prize,
        'ticket_price' => 250,
        'winners_count' => 1,
        'prize_split' => [100],
    ]);
    $winner = CagnotteWinner::create([
        'organization_id' => $organization->id,
        'cagnotte_id' => $cagnotte->id,
        'rank' => 1,
        'user_id' => $awa->id,
        'prize_amount' => 1575,
    ]);
    $url = "/api/v1/orgs/{$organization->id}/cagnottes/{$cagnotte->id}/winners/{$winner->id}/payout";
    $payload = ['method' => 'paydunya', 'withdraw_mode' => 'orange-money-burkina', 'phone' => '+226 70 12 34 56'];

    actingAsUser($admin);
    $this->postJson($url, ['method' => 'paydunya'])->assertJsonValidationErrors(['withdraw_mode', 'phone']);
    $this->postJson($url, $payload)
        ->assertUnprocessable()
        ->assertJsonPath('message', 'Les remises par PayDunya ne sont pas activées sur ce serveur. Enregistrez une remise manuelle.');

    config(['services.paydunya.payouts_enabled' => true]);
    Http::fake([
        '*/api/v2/disburse/get-invoice' => Http::response(['response_code' => '00', 'disburse_token' => 'dis_123']),
        '*/api/v2/disburse/submit-invoice' => Http::response(['response_code' => '00', 'status' => 'pending']),
        '*/api/v2/disburse/check-status' => Http::response(['response_code' => '00', 'status' => 'success', 'token' => 'dis_123', 'transaction_id' => 'TFA-TX-1']),
    ]);

    $this->postJson($url, $payload)
        ->assertOk()
        ->assertJsonPath('data.winners.0.payout.status', 'en_cours')
        ->assertJsonPath('data.winners.0.paid_at', null);

    Http::assertSent(fn ($request) => str_ends_with($request->url(), 'disburse/get-invoice')
        && $request['account_alias'] === '70123456'
        && $request['amount'] === 1575
        && $request['withdraw_mode'] === 'orange-money-burkina');

    // Pas de seconde remise, même manuelle, tant que celle-ci n'a pas de résultat.
    $this->postJson($url, ['method' => 'especes'])->assertUnprocessable();

    $this->postJson('/api/v1/payouts/paydunya/callback', ['hash' => 'faux', 'token' => 'dis_123'])->assertForbidden();
    $this->postJson('/api/v1/payouts/paydunya/callback', ['hash' => hash('sha512', 'cle-principale'), 'status' => 'success', 'token' => 'dis_123'])
        ->assertOk();

    expect($winner->refresh())
        ->paid_at->not->toBeNull()
        ->paid_method->toBe(PaymentMethod::PayDunya)
        ->paid_reference->toBe('TFA-TX-1');
});

it('refuse qu’un trésorier saisisse à la main un paiement PayDunya', function () {
    ['treasurer' => $treasurer, 'awa' => $awa, 'tontine' => $tontine] = startedTontine();
    actingAsUser($treasurer);

    $this->putJson(contributionUrl(contributionOf($tontine, $awa)), ['amount_paid' => 5000, 'method' => 'paydunya'])
        ->assertJsonValidationErrors('method');
});
