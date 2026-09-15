<?php

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;

Route::get('/', function () {
    return view('welcome');
});

// Page affichée par PayDunya après le paiement : le membre revient ensuite dans l'application.
Route::get('/paiement/retour', function (Request $request) {
    return view('payment-return', ['cancelled' => $request->boolean('annule')]);
})->name('payments.return');
