<?php

namespace App\Providers;

use App\Models\Report;
use App\Services\Otp\LogOtpSender;
use App\Services\Otp\MailOtpSender;
use App\Services\Otp\OtpSender;
use Illuminate\Cache\RateLimiting\Limit;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Blade;
use Illuminate\Support\Facades\RateLimiter;
use Illuminate\Support\Facades\View;
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
            if (config('services.otp.channel') === 'mail') {
                return new MailOtpSender;
            }

            if ($this->app->isProduction()) {
                throw new RuntimeException("Aucun canal n'est configuré pour envoyer les codes de connexion (OTP_CHANNEL).");
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

        // Montants du back-office : « 12 500 FCFA », jamais un nombre brut.
        Blade::directive('fcfa', fn (string $expression) => "<?php echo number_format((int) ({$expression}), 0, ',', ' ').' FCFA'; ?>");

        // Pastille des signalements à traiter, présente sur toutes les pages du back-office.
        View::composer('admin.layout', function ($view) {
            $view->with('pendingReports', Auth::check() ? Report::whereNull('reviewed_at')->count() : 0);
        });
    }
}
