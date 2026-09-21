<?php

use App\Enums\FeeOperation;
use App\Enums\Role;
use App\Models\Cagnotte;
use App\Models\CagnotteTemplate;
use App\Models\FeeRule;
use App\Models\Organization;
use App\Models\Report;
use App\Models\User;
use App\Services\Wallet\WalletService;
use Illuminate\Support\Facades\Hash;

function admin(): User
{
    return User::factory()->create([
        'name' => 'Administration',
        'password' => Hash::make('mot-de-passe-solide'),
        'is_super_admin' => true,
    ]);
}

it('garde le back-office fermé sans compte administrateur', function () {
    $this->get('/admin')->assertRedirect('/admin/connexion');

    // Un responsable d'organisation n'est pas un administrateur de la plateforme.
    $organization = Organization::factory()->create();
    $this->actingAs(memberOf($organization, Role::Owner))->get('/admin')->assertForbidden();

    $this->post('/admin/connexion', ['phone' => '70123456', 'password' => 'faux'])
        ->assertSessionHasErrors('phone');
});

it('laisse un administrateur entrer et voir les chiffres de la plateforme', function () {
    $this->post('/admin/connexion', ['phone' => admin()->phone, 'password' => 'mot-de-passe-solide'])
        ->assertRedirect('/admin');

    $this->get('/admin')
        ->assertOk()
        ->assertSee('Tableau de bord')
        ->assertSee('frais perçus ce mois');
});

it('crée un modèle de cagnotte proposé ensuite dans l’application', function () {
    $this->actingAs(admin())
        ->post('/admin/modeles', [
            'name' => 'Tombola du vendredi',
            'mode' => 'gagnants',
            'duration' => 'flash_24h',
            'ticket_price' => 500,
            'winners_count' => 3,
            'prize_split' => '50/30/20',
            'visibility' => 'publique',
            'recurring' => '1',
            'active' => '1',
        ])
        ->assertRedirect(route('admin.templates.index'));

    $template = CagnotteTemplate::firstOrFail();

    expect($template->prize_split)->toBe([50, 30, 20])
        ->and($template->recurring)->toBeTrue();

    // Le modèle apparaît dans l'application.
    actingAsUser(User::factory()->create());
    $this->getJson('/api/v1/cagnotte-templates')->assertJsonPath('data.0.name', 'Tombola du vendredi');
});

it('refuse une répartition qui ne totalise pas 100', function () {
    $this->actingAs(admin())
        ->post('/admin/modeles', [
            'name' => 'Modèle bancal',
            'mode' => 'gagnants',
            'duration' => 'flash_24h',
            'ticket_price' => 500,
            'winners_count' => 2,
            'prize_split' => '70/20',
            'visibility' => 'publique',
        ])
        ->assertSessionHasErrors('prize_split');

    expect(CagnotteTemplate::count())->toBe(0);
});

it('clôt la règle en place quand une nouvelle entre en vigueur', function () {
    $this->actingAs(admin())
        ->post('/admin/frais', [
            'operation' => 'cotisation_en_ligne',
            'rate_bp' => 400,
            'payer' => 'payeur',
            'label' => 'Hausse de septembre',
        ])
        ->assertRedirect(route('admin.fees.index'));

    $rules = FeeRule::where('operation', FeeOperation::ContributionOnline)->orderBy('id')->get();

    expect($rules)->toHaveCount(2)
        ->and($rules->first()->active)->toBeFalse()
        ->and($rules->first()->ends_at)->not->toBeNull()
        ->and($rules->last()->rate_bp)->toBe(400);

    // La nouvelle règle s'applique tout de suite : 4 % de 5 000 font 200.
    actingAsUser(User::factory()->create());
    $this->postJson('/api/v1/fees/simulate', ['operation' => 'cotisation_en_ligne', 'amount' => 5000])
        ->assertJsonPath('data.fee_amount', 200);
});

it('tranche un signalement et rétablit une fiche masquée à tort', function () {
    $organization = Organization::factory()->create();
    $cagnotte = publicCagnotte($organization, memberOf($organization, Role::Admin));

    foreach (range(1, 3) as $ignored) {
        actingAsUser(User::factory()->create());
        $this->postJson('/api/v1/reports', ['type' => 'cagnotte', 'id' => $cagnotte->id, 'reason' => 'arnaque'])->assertCreated();
    }

    expect($cagnotte->refresh()->hidden_at)->not->toBeNull();

    $report = Report::firstOrFail();
    $moderator = admin();

    $this->actingAs($moderator)->get('/admin/signalements')->assertOk()->assertSee('Tombola du vendredi');

    $this->actingAs($moderator)
        ->put("/admin/signalements/{$report->id}", ['decision' => 'conservee', 'note' => 'Vérifié, la cagnotte est réelle.'])
        ->assertRedirect();

    expect($cagnotte->refresh()->hidden_at)->toBeNull()
        // Tous les signalements de la fiche sont clos ensemble, avec leur auteur.
        ->and(Report::whereNull('reviewed_at')->count())->toBe(0)
        ->and(Report::firstOrFail()->reviewed_by)->toBe($moderator->id);

    // La cagnotte est de nouveau visible.
    actingAsUser(User::factory()->create());
    $this->getJson("/api/v1/cagnottes/{$cagnotte->id}")->assertOk();
});

it('suspend un compte, qui ne peut plus se connecter, sans toucher à son argent', function () {
    $sender = fakeOtpSender();
    $member = User::factory()->create(['name' => 'Awa']);
    fundWallet($member, 15000);

    $this->actingAs(admin())
        ->put("/admin/membres/{$member->id}", ['action' => 'bloquer', 'reason' => 'Signalements répétés'])
        ->assertRedirect();

    expect($member->refresh()->blocked_at)->not->toBeNull()
        ->and(app(WalletService::class)->balance($member))->toBe(15000);

    // Le code part quand même : dire « ce compte est suspendu » à qui tape un numéro
    // renseignerait n'importe qui. La porte se ferme à la vérification.
    $this->postJson('/api/v1/auth/otp/request', ['phone' => $member->phone])->assertSuccessful();
    $this->postJson('/api/v1/auth/otp/verify', ['phone' => $member->phone, 'code' => $sender->codes[$member->phone]])
        ->assertUnprocessable()
        ->assertJsonValidationErrors('phone');

    // La suspension se lève.
    $this->actingAs(admin())->put("/admin/membres/{$member->id}", ['action' => 'debloquer'])->assertRedirect();
    expect($member->refresh()->blocked_at)->toBeNull();
});

it('affiche le contrôle du grand livre et la fiche d’un membre', function () {
    $member = User::factory()->create(['name' => 'Binta']);
    fundWallet($member, 8000);

    $this->actingAs(admin())->get('/admin/portefeuille')->assertOk()->assertSee('équilibré');
    $this->actingAs(admin())->get("/admin/membres/{$member->id}")->assertOk()->assertSee('8 000 FCFA');
});

it('donne et retire l’accès au back-office depuis la ligne de commande', function () {
    $this->artisan('admin:create', ['--phone' => '70998877', '--password' => 'un-mot-de-passe-long'])
        ->assertSuccessful();

    $user = User::where('phone', '+22670998877')->firstOrFail();
    expect($user->is_super_admin)->toBeTrue();

    $this->post('/admin/connexion', ['phone' => '70 99 88 77', 'password' => 'un-mot-de-passe-long'])
        ->assertRedirect('/admin');

    $this->artisan('admin:create', ['--phone' => '70998877', '--revoke' => true])->assertSuccessful();
    expect($user->refresh()->is_super_admin)->toBeFalse();

    // Un mot de passe trop court est refusé.
    $this->artisan('admin:create', ['--phone' => '70112233', '--password' => 'court'])->assertFailed();
});
