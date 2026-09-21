<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Support\PhoneNumber;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\RateLimiter;
use Illuminate\Validation\ValidationException;
use Illuminate\View\View;

/**
 * Entrée du back-office : numéro et mot de passe.
 *
 * Les membres se connectent par code à usage unique ; le back-office, lui, demande un mot de
 * passe, parce qu'il ouvre les comptes de tout le monde et qu'un téléphone se perd.
 */
class SessionController extends Controller
{
    private const MAX_ATTEMPTS = 5;

    public function create(): View|RedirectResponse
    {
        return Auth::user()?->is_super_admin
            ? redirect()->route('admin.dashboard')
            : view('admin.login');
    }

    public function store(Request $request): RedirectResponse
    {
        $data = $request->validate([
            'phone' => ['required', 'string', 'max:20'],
            'password' => ['required', 'string'],
        ]);

        $phone = PhoneNumber::normalize($data['phone']) ?? $data['phone'];
        $key = 'admin-login:'.$phone.'|'.$request->ip();

        if (RateLimiter::tooManyAttempts($key, self::MAX_ATTEMPTS)) {
            $minutes = (int) ceil(RateLimiter::availableIn($key) / 60);

            throw ValidationException::withMessages(['phone' => "Trop de tentatives. Réessayez dans {$minutes} min."]);
        }

        if (! Auth::attempt(['phone' => $phone, 'password' => $data['password'], 'is_super_admin' => true], true)) {
            RateLimiter::hit($key, 900);

            throw ValidationException::withMessages(['phone' => 'Numéro ou mot de passe incorrect.']);
        }

        RateLimiter::clear($key);
        $request->session()->regenerate();

        return redirect()->intended(route('admin.dashboard'));
    }

    public function destroy(Request $request): RedirectResponse
    {
        Auth::logout();
        $request->session()->invalidate();
        $request->session()->regenerateToken();

        return redirect()->route('admin.login');
    }
}
