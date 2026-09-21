<?php

namespace App\Http\Controllers\Api;

use App\Enums\FeeOperation;
use App\Http\Controllers\Controller;
use App\Services\Fees\FeeEngine;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

/**
 * Grille des frais de service et simulation avant paiement.
 *
 * La grille est lisible sans être connecté : personne ne doit avoir à créer un compte
 * pour savoir ce que l'application prélève.
 */
class FeeController extends Controller
{
    public function __construct(private FeeEngine $fees) {}

    public function index(Request $request): JsonResponse
    {
        $organizationId = $this->organizationId($request);

        return response()->json([
            'data' => [
                'operations' => $this->fees->grid($organizationId),
                'note' => 'Les frais ne portent que sur l’argent qui passe par l’application. '
                    .'Une cotisation remise en espèces au trésorier ne coûte rien.',
            ],
        ]);
    }

    public function simulate(Request $request): JsonResponse
    {
        $data = $request->validate([
            'operation' => ['required', Rule::enum(FeeOperation::class)],
            'amount' => ['required', 'integer', 'min:0', 'max:100000000'],
        ]);

        $quote = $this->fees->quote(
            FeeOperation::from($data['operation']),
            (int) $data['amount'],
            $this->organizationId($request),
        );

        return response()->json(['data' => $quote->toArray()]);
    }

    /** Les frais d'une organisation peuvent être réduits : on ne les applique qu'à ses membres. */
    private function organizationId(Request $request): ?int
    {
        $requested = $request->integer('organization_id');
        $user = $request->user();

        if ($requested <= 0 || $user === null) {
            return null;
        }

        return $user->memberships()->where('organization_id', $requested)->exists() ? $requested : null;
    }
}
