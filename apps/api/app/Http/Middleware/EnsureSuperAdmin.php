<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * Le back-office n'est ouvert qu'aux comptes marqués administrateurs de la plateforme.
 *
 * Être responsable d'une organisation n'y donne aucun droit : ce sont deux pouvoirs
 * différents, et les confondre reviendrait à laisser n'importe quel trésorier lire les
 * comptes de tout le monde.
 */
class EnsureSuperAdmin
{
    public function handle(Request $request, Closure $next): Response
    {
        $user = $request->user();

        if ($user === null) {
            return redirect()->route('admin.login');
        }

        abort_unless($user->is_super_admin, 403, 'Ce compte n’a pas accès au back-office.');

        return $next($request);
    }
}
