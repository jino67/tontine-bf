<?php

use App\Http\Controllers\Api\AcceptInvitationController;
use App\Http\Controllers\Api\Auth\OtpController;
use App\Http\Controllers\Api\CagnotteContributionController;
use App\Http\Controllers\Api\CagnotteController;
use App\Http\Controllers\Api\CagnotteDrawController;
use App\Http\Controllers\Api\CagnotteHandoverController;
use App\Http\Controllers\Api\CagnotteTemplateController;
use App\Http\Controllers\Api\CagnotteWinnerController;
use App\Http\Controllers\Api\ContributionController;
use App\Http\Controllers\Api\CycleController;
use App\Http\Controllers\Api\CyclePayoutController;
use App\Http\Controllers\Api\DiscoverController;
use App\Http\Controllers\Api\DrawController;
use App\Http\Controllers\Api\FeeController;
use App\Http\Controllers\Api\InvitationController;
use App\Http\Controllers\Api\JoinRequestController;
use App\Http\Controllers\Api\MeController;
use App\Http\Controllers\Api\MemberController;
use App\Http\Controllers\Api\MyContributionController;
use App\Http\Controllers\Api\OrganizationController;
use App\Http\Controllers\Api\PayDunyaWebhookController;
use App\Http\Controllers\Api\PaymentController;
use App\Http\Controllers\Api\PublicCagnotteController;
use App\Http\Controllers\Api\ReportController;
use App\Http\Controllers\Api\ShareLinkController;
use App\Http\Controllers\Api\SharingController;
use App\Http\Controllers\Api\StartTontineController;
use App\Http\Controllers\Api\TontineController;
use App\Http\Controllers\Api\TontineMemberController;
use App\Http\Controllers\Api\WalletController;
use App\Http\Controllers\Api\WalletMoneyController;
use Illuminate\Support\Facades\Route;

Route::prefix('v1')->group(function () {
    Route::middleware('throttle:otp')->group(function () {
        Route::post('auth/otp/request', [OtpController::class, 'sendCode']);
        Route::post('auth/otp/verify', [OtpController::class, 'verifyCode']);
    });

    // Notifications signées de PayDunya (sans jeton de connexion).
    Route::middleware('throttle:120,1')->group(function () {
        Route::post('payments/paydunya/ipn', [PayDunyaWebhookController::class, 'payment'])->name('payments.paydunya.ipn');
        Route::post('payouts/paydunya/callback', [PayDunyaWebhookController::class, 'payout'])->name('payouts.paydunya.callback');
    });

    // Fiche publique d'un lien partagé, lisible sans connexion.
    Route::get('links/{code}', ShareLinkController::class)->middleware('throttle:60,1');

    // Grille des frais : personne ne doit créer un compte pour savoir ce que l'application prélève.
    Route::get('fees', [FeeController::class, 'index'])->middleware('throttle:60,1');

    Route::middleware('auth:sanctum')->group(function () {
        Route::post('auth/logout', [OtpController::class, 'logout']);
        Route::get('me', [MeController::class, 'show']);
        Route::patch('me', [MeController::class, 'update']);
        Route::get('me/contributions', MyContributionController::class);
        Route::post('fees/simulate', [FeeController::class, 'simulate']);

        Route::get('orgs', [OrganizationController::class, 'index']);
        Route::post('orgs', [OrganizationController::class, 'store']);
        Route::post('invitations/{code}/accept', AcceptInvitationController::class);

        // Annuaire public, demandes d'adhésion et signalements : le demandeur n'est pas encore membre.
        Route::get('discover', DiscoverController::class);
        Route::get('join-requests', [JoinRequestController::class, 'mine']);
        Route::post('join-requests', [JoinRequestController::class, 'store']);
        Route::delete('join-requests/{joinRequest}', [JoinRequestController::class, 'destroy']);
        Route::post('reports', [ReportController::class, 'store']);

        // Cagnottes ouvertes à tous : participer est un paiement, pas une adhésion.
        Route::get('cagnottes/{cagnotte}', [PublicCagnotteController::class, 'show']);
        Route::post('cagnottes/{cagnotte}/pay', [PublicCagnotteController::class, 'pay']);
        Route::post('cagnottes/{cagnotte}/pay-with-balance', [PublicCagnotteController::class, 'payWithBalance']);
        Route::get('cagnotte-templates', CagnotteTemplateController::class);
        // Suivi d'un paiement par celui qui l'a lancé, même hors de son organisation.
        Route::get('payments/{payment}', [PaymentController::class, 'mine']);

        // Portefeuille : solde, historique, transferts, et les deux portes de l'argent.
        Route::get('wallet', [WalletController::class, 'show']);
        Route::get('wallet/transactions', [WalletController::class, 'transactions']);
        Route::post('wallet/transfer', [WalletController::class, 'transfer']);
        Route::put('wallet/payout-phone', [WalletController::class, 'payoutPhone']);
        Route::post('wallet/deposit', [WalletMoneyController::class, 'deposit']);
        Route::post('wallet/withdraw', [WalletMoneyController::class, 'withdraw']);

        // scopeBindings : chaque ressource imbriquée est cherchée dans son parent,
        // une tontine ou une cagnotte d'une autre organisation répond donc 404.
        Route::prefix('orgs/{organization}')->middleware('org.member')->scopeBindings()->group(function () {
            Route::get('/', [OrganizationController::class, 'show']);
            Route::get('members', [MemberController::class, 'index']);
            Route::patch('members/{membership}', [MemberController::class, 'update']);
            Route::post('invitations', [InvitationController::class, 'store']);
            Route::put('sharing', [SharingController::class, 'organization']);
            Route::get('join-requests', [JoinRequestController::class, 'index']);
            Route::post('join-requests/{joinRequest}/approve', [JoinRequestController::class, 'approve']);
            Route::post('join-requests/{joinRequest}/reject', [JoinRequestController::class, 'reject']);

            Route::get('tontines', [TontineController::class, 'index']);
            Route::post('tontines', [TontineController::class, 'store']);
            Route::get('tontines/{tontine}', [TontineController::class, 'show']);
            Route::post('tontines/{tontine}/members', [TontineMemberController::class, 'store']);
            Route::post('tontines/{tontine}/start', StartTontineController::class);
            Route::put('tontines/{tontine}/sharing', [SharingController::class, 'tontine']);

            Route::get('tontines/{tontine}/cycles', [CycleController::class, 'index']);
            Route::get('tontines/{tontine}/cycles/{cycle}', [CycleController::class, 'show']);
            Route::put('tontines/{tontine}/cycles/{cycle}/contributions/{contribution}', [ContributionController::class, 'update']);
            Route::post('tontines/{tontine}/cycles/{cycle}/contributions/{contribution}/confirm', [ContributionController::class, 'confirm']);
            Route::post('tontines/{tontine}/cycles/{cycle}/contributions/{contribution}/pay', [PaymentController::class, 'payContribution']);
            Route::post('tontines/{tontine}/cycles/{cycle}/contributions/{contribution}/pay-with-balance', [PaymentController::class, 'payContributionFromBalance']);
            Route::post('tontines/{tontine}/cycles/{cycle}/payout', CyclePayoutController::class);
            Route::post('cagnottes/{cagnotte}/pay', [PaymentController::class, 'payCagnotte']);
            Route::post('cagnottes/{cagnotte}/pay-with-balance', [PaymentController::class, 'payCagnotteFromBalance']);
            Route::get('payments/{payment}', [PaymentController::class, 'show']);

            Route::get('tontines/{tontine}/draw', [DrawController::class, 'show']);
            Route::post('tontines/{tontine}/draw', [DrawController::class, 'store']);
            Route::post('tontines/{tontine}/draw/reveal', [DrawController::class, 'reveal']);

            Route::get('cagnottes', [CagnotteController::class, 'index']);
            Route::post('cagnottes', [CagnotteController::class, 'store']);
            Route::get('cagnottes/{cagnotte}', [CagnotteController::class, 'show']);
            Route::post('cagnottes/{cagnotte}/close', [CagnotteController::class, 'close']);
            Route::put('cagnottes/{cagnotte}/sharing', [SharingController::class, 'cagnotte']);
            Route::post('cagnottes/{cagnotte}/contributions', [CagnotteContributionController::class, 'store']);
            Route::put('cagnottes/{cagnotte}/contributions/{contribution}', [CagnotteContributionController::class, 'update']);
            Route::post('cagnottes/{cagnotte}/contributions/{contribution}/confirm', [CagnotteContributionController::class, 'confirm']);
            Route::post('cagnottes/{cagnotte}/handover', [CagnotteHandoverController::class, 'store']);
            Route::post('cagnottes/{cagnotte}/handover/confirm', [CagnotteHandoverController::class, 'confirm']);
            Route::post('cagnottes/{cagnotte}/draw', [CagnotteDrawController::class, 'store']);
            Route::post('cagnottes/{cagnotte}/draw/reveal', [CagnotteDrawController::class, 'reveal']);
            Route::post('cagnottes/{cagnotte}/winners/{winner}/payout', [CagnotteWinnerController::class, 'payout']);
            Route::post('cagnottes/{cagnotte}/winners/{winner}/confirm', [CagnotteWinnerController::class, 'confirm']);
        });
    });
});
