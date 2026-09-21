<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\ShareLinks;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/** Lecture publique d'un code partagé, sans connexion : la fiche, rien de plus. */
class ShareLinkController extends Controller
{
    public function __invoke(Request $request, string $code): JsonResponse
    {
        $link = ShareLinks::resolve($code, $request->user());

        abort_if($link === null, 404, 'Ce lien n’est pas valable, ou il a été retiré.');

        return response()->json($link);
    }
}
