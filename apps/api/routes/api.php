<?php

use App\Http\Controllers\Api\AcceptInvitationController;
use App\Http\Controllers\Api\Auth\OtpController;
use App\Http\Controllers\Api\CagnotteContributionController;
use App\Http\Controllers\Api\CagnotteController;
use App\Http\Controllers\Api\CagnotteDrawController;
use App\Http\Controllers\Api\CagnotteHandoverController;
use App\Http\Controllers\Api\CagnotteWinnerController;
use App\Http\Controllers\Api\ContributionController;
use App\Http\Controllers\Api\CycleController;
use App\Http\Controllers\Api\DrawController;
use App\Http\Controllers\Api\InvitationController;
use App\Http\Controllers\Api\MeController;
use App\Http\Controllers\Api\MemberController;
use App\Http\Controllers\Api\MyContributionController;
use App\Http\Controllers\Api\OrganizationController;
use App\Http\Controllers\Api\StartTontineController;
use App\Http\Controllers\Api\TontineController;
use App\Http\Controllers\Api\TontineMemberController;
use Illuminate\Support\Facades\Route;

Route::prefix('v1')->group(function () {
    Route::middleware('throttle:otp')->group(function () {
        Route::post('auth/otp/request', [OtpController::class, 'sendCode']);
        Route::post('auth/otp/verify', [OtpController::class, 'verifyCode']);
    });

    Route::middleware('auth:sanctum')->group(function () {
        Route::post('auth/logout', [OtpController::class, 'logout']);
        Route::get('me', [MeController::class, 'show']);
        Route::patch('me', [MeController::class, 'update']);
        Route::get('me/contributions', MyContributionController::class);

        Route::get('orgs', [OrganizationController::class, 'index']);
        Route::post('orgs', [OrganizationController::class, 'store']);
        Route::post('invitations/{code}/accept', AcceptInvitationController::class);

        // scopeBindings : chaque ressource imbriquée est cherchée dans son parent,
        // une tontine ou une cagnotte d'une autre organisation répond donc 404.
        Route::prefix('orgs/{organization}')->middleware('org.member')->scopeBindings()->group(function () {
            Route::get('/', [OrganizationController::class, 'show']);
            Route::get('members', [MemberController::class, 'index']);
            Route::patch('members/{membership}', [MemberController::class, 'update']);
            Route::post('invitations', [InvitationController::class, 'store']);

            Route::get('tontines', [TontineController::class, 'index']);
            Route::post('tontines', [TontineController::class, 'store']);
            Route::get('tontines/{tontine}', [TontineController::class, 'show']);
            Route::post('tontines/{tontine}/members', [TontineMemberController::class, 'store']);
            Route::post('tontines/{tontine}/start', StartTontineController::class);

            Route::get('tontines/{tontine}/cycles', [CycleController::class, 'index']);
            Route::get('tontines/{tontine}/cycles/{cycle}', [CycleController::class, 'show']);
            Route::put('tontines/{tontine}/cycles/{cycle}/contributions/{contribution}', [ContributionController::class, 'update']);
            Route::post('tontines/{tontine}/cycles/{cycle}/contributions/{contribution}/confirm', [ContributionController::class, 'confirm']);

            Route::get('tontines/{tontine}/draw', [DrawController::class, 'show']);
            Route::post('tontines/{tontine}/draw', [DrawController::class, 'store']);
            Route::post('tontines/{tontine}/draw/reveal', [DrawController::class, 'reveal']);

            Route::get('cagnottes', [CagnotteController::class, 'index']);
            Route::post('cagnottes', [CagnotteController::class, 'store']);
            Route::get('cagnottes/{cagnotte}', [CagnotteController::class, 'show']);
            Route::post('cagnottes/{cagnotte}/close', [CagnotteController::class, 'close']);
            Route::post('cagnottes/{cagnotte}/contributions', [CagnotteContributionController::class, 'store']);
            Route::put('cagnottes/{cagnotte}/contributions/{contribution}', [CagnotteContributionController::class, 'update']);
            Route::post('cagnottes/{cagnotte}/contributions/{contribution}/confirm', [CagnotteContributionController::class, 'confirm']);
            Route::post('cagnottes/{cagnotte}/handover', [CagnotteHandoverController::class, 'store']);
            Route::post('cagnottes/{cagnotte}/handover/confirm', [CagnotteHandoverController::class, 'confirm']);
            Route::put('cagnottes/{cagnotte}/designations', [CagnotteController::class, 'designations']);
            Route::post('cagnottes/{cagnotte}/draw', [CagnotteDrawController::class, 'store']);
            Route::post('cagnottes/{cagnotte}/draw/reveal', [CagnotteDrawController::class, 'reveal']);
            Route::post('cagnottes/{cagnotte}/winners/{winner}/payout', [CagnotteWinnerController::class, 'payout']);
            Route::post('cagnottes/{cagnotte}/winners/{winner}/confirm', [CagnotteWinnerController::class, 'confirm']);
        });
    });
});
