<?php

namespace App\Providers;

use App\Services\Otp\LogOtpSender;
use App\Services\Otp\OtpSender;
use Illuminate\Cache\RateLimiting\Limit;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\RateLimiter;
use Illuminate\Support\ServiceProvider;
use RuntimeException;

class AppServiceProvider extends ServiceProvider
{
    /**
     * Register any application services.
     */
    public function register(): void
    {
        $this->app->bind(OtpSender::class, function () {
            if ($this->app->isProduction()) {
                throw new RuntimeException("Aucun fournisseur SMS n'est configuré pour envoyer les codes OTP.");
            }

            return new LogOtpSender;
        });
    }

    /**
     * Bootstrap any application services.
     */
    public function boot(): void
    {
        RateLimiter::for('otp', fn (Request $request) => Limit::perMinute(10)->by($request->ip()));
    }
}
