<?php

namespace App\Http\Controllers;

use App\Services\ShareLinks;
use Illuminate\Contracts\View\View;

/**
 * Page ouverte quand on touche un lien partagé depuis WhatsApp ou ailleurs.
 *
 * Elle montre la fiche publique, puis renvoie vers l'application : installée, l'App Link
 * ouvre directement le bon écran ; absente, la page propose de l'installer.
 */
class ShareLandingController extends Controller
{
    private const KINDS = ['t' => 'tontine', 'c' => 'cagnotte', 'o' => 'organisation', 'i' => 'invitation'];

    public function show(string $kind, string $code): View
    {
        $link = ShareLinks::resolve($code);

        abort_if($link === null || (self::KINDS[$kind] ?? null) !== $link['type'], 404);

        return view('share', [
            'type' => $link['type'],
            'item' => $link['data'],
            'code' => $code,
            'apkUrl' => config('services.app_links.apk_url'),
        ]);
    }
}
