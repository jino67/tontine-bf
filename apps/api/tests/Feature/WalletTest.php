<?php

use App\Enums\PaymentStatus;
use App\Enums\WalletStatus;
use App\Models\Account;
use App\Models\LedgerEntry;
use App\Models\Payment;
use App\Models\Payout;
use App\Models\User;
use App\Models\WalletTransaction;
use App\Services\PayoutService;
use App\Services\Wallet\WalletService;
use Illuminate\Support\Facades\Http;

/** Garnit un solde comme le ferait un dépôt encaissé par PayDunya. */
function fundWallet(User $user, int $amount): void
{
    $payment = Payment::create([
        'user_id' => $user->id,
        'payable_type' => $user->getMorphClass(),
        'payable_id' => $user->id,
        'amount' => $amount,
        'base_amount' => $amount,
        'fee_amount' => 0,
        'status' => PaymentStatus::Paid,
        'paid_at' => now(),
    ]);

    app(WalletService::class)->applyDeposit($user, $payment);
}

it('ouvre un portefeuille vide, avec le dépôt libre fermé', function () {
    $user = actingAsUser(User::factory()->create());

    $this->getJson('/api/v1/wallet')
        ->assertOk()
        ->assertJsonPath('data.balance', 0)
        ->assertJsonPath('data.level', 0)
        ->assertJsonPath('data.max_balance', 100000)
        ->assertJsonPath('data.deposits_enabled', false);

    $this->postJson('/api/v1/wallet/deposit', ['amount' => 5000])
        ->assertUnprocessable()
        ->assertJsonPath('message', 'Le dépôt libre n’est pas encore ouvert. Votre solde se garnit avec vos gains, vos tours reçus et les remboursements.');

    expect(app(WalletService::class)->balance($user))->toBe(0);
});

it('règle une cotisation depuis le solde, en retenant 1 % de frais', function () {
    ['awa' => $awa, 'tontine' => $tontine, 'organization' => $organization] = startedTontine();
    $contribution = contributionOf($tontine, $awa);
    fundWallet($awa, 10000);

    actingAsUser($awa);
    $this->postJson(contributionUrl($contribution).'/pay-with-balance')
        ->assertCreated()
        ->assertJsonPath('data.type', 'cotisation')
        ->assertJsonPath('data.amount', 5000)
        ->assertJsonPath('data.fee_amount', 50)
        ->assertJsonPath('data.balance_after', 4950);

    expect($contribution->refresh())
        ->amount_paid->toBe(5000)
        ->confirmed_at->not->toBeNull()
        // Les 5 000 sont détenus par l'organisation jusqu'au versement du tour.
        ->and(Account::of($organization)->balance())->toBe(5000)
        ->and(Account::of($awa)->balance())->toBe(4950);

    // Une deuxième fois, il n'y a plus rien à payer.
    $this->postJson(contributionUrl($contribution).'/pay-with-balance')->assertUnprocessable();
});

it('refuse de payer au-delà du solde', function () {
    ['awa' => $awa, 'tontine' => $tontine] = startedTontine();
    fundWallet($awa, 1000);

    actingAsUser($awa);
    $this->postJson(contributionUrl(contributionOf($tontine, $awa)).'/pay-with-balance')
        ->assertUnprocessable()
        ->assertJsonPath('message', 'Votre solde est insuffisant : il manque 4 050 FCFA.');
});

it('transfère entre membres sans frais, et refuse le transfert à soi-même', function () {
    $awa = User::factory()->create(['name' => 'Awa']);
    $binta = User::factory()->create(['name' => 'Binta', 'phone' => '+22670112233']);
    fundWallet($awa, 20000);

    actingAsUser($awa);
    $this->postJson('/api/v1/wallet/transfer', ['phone' => '70 11 22 33', 'amount' => 7500, 'note' => 'Merci'])
        ->assertCreated()
        ->assertJsonPath('data.type', 'transfert_envoye')
        ->assertJsonPath('data.fee_amount', 0)
        ->assertJsonPath('data.balance_after', 12500);

    expect(app(WalletService::class)->balance($binta))->toBe(7500);

    $this->postJson('/api/v1/wallet/transfer', ['phone' => $awa->phone, 'amount' => 1000])
        ->assertUnprocessable()
        ->assertJsonPath('message', 'Vous ne pouvez pas vous envoyer de l’argent à vous-même.');

    $this->postJson('/api/v1/wallet/transfer', ['phone' => '70 99 99 99', 'amount' => 1000])
        ->assertUnprocessable()
        ->assertJsonPath('message', 'Aucun membre ne correspond à ce numéro. Invitez-le d’abord.');
});

it('verse le tour au bénéficiaire, une seule fois et seulement ce qui a transité par l’application', function () {
    ['awa' => $awa, 'binta' => $binta, 'treasurer' => $treasurer, 'tontine' => $tontine] = startedTontine();
    $cycle = $tontine->cycles()->where('number', 1)->firstOrFail();

    // Awa paie depuis son solde, Binta remet ses 5 000 en espèces au trésorier.
    fundWallet($awa, 10000);
    actingAsUser($awa);
    $this->postJson(contributionUrl(contributionOf($tontine, $awa)).'/pay-with-balance')->assertCreated();

    actingAsUser($treasurer);
    $this->putJson(contributionUrl(contributionOf($tontine, $binta)), ['amount_paid' => 5000, 'method' => 'especes'])->assertOk();

    $url = tontineUrl($tontine, "/cycles/{$cycle->id}/payout");

    // Seuls les 5 000 reçus par l'application sont versés, moins 1 % de frais.
    $this->postJson($url)
        ->assertCreated()
        ->assertJsonPath('data.type', 'tour')
        ->assertJsonPath('data.amount', 4950)
        ->assertJsonPath('data.fee_amount', 50);

    $this->postJson($url)->assertUnprocessable()->assertJsonPath('message', 'Le versement de ce tour est déjà enregistré.');

    expect(app(WalletService::class)->balance($awa))->toBe(4950 + 4950);
});

it('retire vers mobile money, et rend l’argent quand l’opérateur refuse', function () {
    fakePayDunyaConfig(payouts: true);
    $awa = actingAsUser(User::factory()->create());
    fundWallet($awa, 30000);
    $awa->update(['payout_phone' => $awa->phone, 'payout_mode' => 'orange-money-burkina']);

    Http::fake([
        '*/api/v2/disburse/get-invoice' => Http::response(['response_code' => '00', 'disburse_token' => 'dis_1']),
        '*/api/v2/disburse/submit-invoice' => Http::response(['response_code' => '00', 'status' => 'pending']),
        '*/api/v2/disburse/check-status' => Http::response(['response_code' => '00', 'status' => 'failed', 'response_text' => 'Compte introuvable']),
    ]);

    // 2,5 % de 10 000 : 250 de frais, 10 250 quittent le solde tout de suite.
    $this->postJson('/api/v1/wallet/withdraw', ['amount' => 10000])
        ->assertCreated()
        ->assertJsonPath('data.status', 'en_attente')
        ->assertJsonPath('data.fee_amount', 250);

    expect(app(WalletService::class)->balance($awa))->toBe(19750);

    // L'opérateur refuse : la somme revient entière, frais compris.
    app(PayoutService::class)->refresh(Payout::firstOrFail());

    $transaction = WalletTransaction::where('type', 'retrait')->firstOrFail();

    expect($transaction->status)->toBe(WalletStatus::Failed)
        ->and($transaction->failure_reason)->toBe('Compte introuvable')
        ->and(app(WalletService::class)->balance($awa))->toBe(30000);
});

it('refuse un retrait sans numéro enregistré, et au-delà du plafond du jour', function () {
    $awa = actingAsUser(User::factory()->create());
    fundWallet($awa, 100000);

    $this->postJson('/api/v1/wallet/withdraw', ['amount' => 10000])
        ->assertUnprocessable()
        ->assertJsonPath('message', 'Enregistrez d’abord le numéro mobile money qui recevra l’argent.');

    $awa->update(['payout_phone' => $awa->phone, 'payout_mode' => 'orange-money-burkina']);

    // Le niveau 0 s'arrête à 50 000 FCFA de retrait par jour.
    $this->postJson('/api/v1/wallet/withdraw', ['amount' => 60000])
        ->assertUnprocessable()
        ->assertJsonPath('message', 'Vous ne pouvez pas retirer plus de 50 000 FCFA par jour.');
});

it('tient un grand livre équilibré, et un solde plafonné au niveau du compte', function () {
    $awa = User::factory()->create();
    fundWallet($awa, 90000);

    // Chaque mouvement s'équilibre : autant au débit qu'au crédit.
    foreach (LedgerEntry::all()->groupBy('transaction_ref') as $entries) {
        $debits = $entries->where('direction', 'debit')->sum('amount');
        $credits = $entries->where('direction', 'credit')->sum('amount');
        expect($debits)->toBe($credits);
    }

    $binta = actingAsUser(User::factory()->create());
    fundWallet($binta, 95000);

    // 95 000 + 10 000 dépasserait le plafond de 100 000 du niveau 0.
    $this->postJson('/api/v1/wallet/transfer', ['phone' => $binta->phone, 'amount' => 10000]);

    actingAsUser($awa);
    $this->postJson('/api/v1/wallet/transfer', ['phone' => $binta->phone, 'amount' => 10000])
        ->assertUnprocessable()
        ->assertJsonPath('message', 'Votre solde ne peut pas dépasser 100 000 FCFA. Retirez une partie de votre argent avant de recevoir plus.');
});

it('demande un code avant de changer le numéro de retrait', function () {
    $sender = fakeOtpSender();
    $awa = actingAsUser(User::factory()->create());

    $this->putJson('/api/v1/wallet/payout-phone', ['phone' => '70 55 44 33', 'withdraw_mode' => 'orange-money-burkina'])
        ->assertStatus(202);

    expect($awa->refresh()->payout_phone)->toBeNull();

    $this->putJson('/api/v1/wallet/payout-phone', [
        'phone' => '70 55 44 33',
        'withdraw_mode' => 'orange-money-burkina',
        'code' => $sender->codes[$awa->phone],
    ])->assertOk()->assertJsonPath('data.payout_phone', '+22670554433');

    // Numéro fraîchement changé : le premier retrait attend le délai de sécurité.
    $this->postJson('/api/v1/wallet/withdraw', ['amount' => 5000])
        ->assertUnprocessable()
        ->assertJsonPath('message', 'Ce numéro de retrait vient d’être changé. Le premier retrait sera possible dans 24 h.');
});

it('refuse l’accès au portefeuille sans être connecté', function () {
    $this->getJson('/api/v1/wallet')->assertUnauthorized();
    $this->postJson('/api/v1/wallet/transfer', ['phone' => '70123456', 'amount' => 100])->assertUnauthorized();
});
