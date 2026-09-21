<?php

use App\Http\Controllers\ShareLandingController;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;

Route::get('/', function () {
    return view('welcome');
});

// Page affichée par PayDunya après le paiement : le membre revient ensuite dans l'application.
Route::get('/paiement/retour', function (Request $request) {
    return view('payment-return', ['cancelled' => $request->boolean('annule')]);
})->name('payments.return');

// Liens partagés : /t/<code> tontine, /c/<code> cagnotte, /o/<code> organisation, /i/<code> invitation.
Route::get('/{kind}/{code}', [ShareLandingController::class, 'show'])
    ->whereIn('kind', ['t', 'c', 'o', 'i'])
    ->where('code', '[A-Za-z0-9]{6,12}')
    ->name('share.show');

// Ouverture directe de l'application Android sur les liens ci-dessus, sans passer par le navigateur.
Route::get('/.well-known/assetlinks.json', function () {
    $fingerprints = array_values(array_filter(array_map(
        'trim',
        explode(',', (string) config('services.app_links.android_fingerprints')),
    )));

    return response()->json($fingerprints === [] ? [] : [[
        'relation' => ['delegate_permission/common.handle_all_urls'],
        'target' => [
            'namespace' => 'android_app',
            'package_name' => config('services.app_links.android_package'),
            'sha256_cert_fingerprints' => $fingerprints,
        ],
    ]]);
})->name('assetlinks');
