<?php

use App\Http\Controllers\Admin\DashboardController;
use App\Http\Controllers\Admin\FeeController;
use App\Http\Controllers\Admin\MemberController;
use App\Http\Controllers\Admin\ModerationController;
use App\Http\Controllers\Admin\SessionController;
use App\Http\Controllers\Admin\TemplateController;
use App\Http\Controllers\Admin\WalletController;
use Illuminate\Support\Facades\Route;

/*
|--------------------------------------------------------------------------
| Back-office de la plateforme
|--------------------------------------------------------------------------
|
| Servi à /admin sur le même domaine que l'API. Réservé aux comptes marqués
| administrateurs : être responsable d'une organisation n'y donne aucun droit.
|
*/

Route::get('connexion', [SessionController::class, 'create'])->name('login');
Route::post('connexion', [SessionController::class, 'store'])->middleware('throttle:10,1')->name('login.store');

// EnsureSuperAdmin renvoie lui-même vers la connexion : pas besoin du middleware « auth »,
// dont la redirection viserait une route « login » qui n'existe pas côté API.
Route::middleware('admin')->group(function () {
    Route::post('deconnexion', [SessionController::class, 'destroy'])->name('logout');

    Route::get('/', DashboardController::class)->name('dashboard');

    Route::get('signalements', [ModerationController::class, 'index'])->name('moderation.index');
    Route::put('signalements/{report}', [ModerationController::class, 'update'])->name('moderation.update');

    Route::get('modeles', [TemplateController::class, 'index'])->name('templates.index');
    Route::post('modeles', [TemplateController::class, 'store'])->name('templates.store');
    Route::put('modeles/{template}', [TemplateController::class, 'update'])->name('templates.update');
    Route::delete('modeles/{template}', [TemplateController::class, 'destroy'])->name('templates.destroy');

    Route::get('frais', [FeeController::class, 'index'])->name('fees.index');
    Route::post('frais', [FeeController::class, 'store'])->name('fees.store');
    Route::delete('frais/{rule}', [FeeController::class, 'destroy'])->name('fees.destroy');

    Route::get('portefeuille', [WalletController::class, 'index'])->name('wallet.index');
    Route::post('portefeuille/retraits/{transaction}/relire', [WalletController::class, 'refresh'])->name('wallet.refresh');

    Route::get('membres', [MemberController::class, 'index'])->name('members.index');
    Route::get('membres/{member}', [MemberController::class, 'show'])->name('members.show');
    Route::put('membres/{member}', [MemberController::class, 'update'])->name('members.update');
});
