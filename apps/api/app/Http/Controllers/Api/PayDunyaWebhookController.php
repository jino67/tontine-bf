<?php

namespace App\Http\Controllers\Api;

use App\Exceptions\DomainRuleException;
use App\Http\Controllers\Controller;
use App\Models\Payment;
use App\Models\Payout;
use App\Services\PayDunya\PayDunyaClient;
use App\Services\PaymentService;
use App\Services\PayoutService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * Notifications de PayDunya. La signature est vérifiée, puis le statut est relu auprès de l'API :
 * le contenu de la notification ne sert qu'à retrouver l'opération.
 */
class PayDunyaWebhookController extends Controller
{
    public function payment(Request $request, PayDunyaClient $client, PaymentService $payments): JsonResponse
    {
        $data = $request->input('data', $request->all());

        if (! $client->isAuthentic(data_get($data, 'hash'))) {
            return response()->json(['message' => 'Signature invalide.'], 403);
        }

        $payment = Payment::where('token', data_get($data, 'invoice.token'))->first();

        if ($payment !== null) {
            try {
                $payments->refresh($payment);
            } catch (DomainRuleException) {
                // Statut illisible pour l'instant : le téléphone du membre le relira au retour.
            }
        }

        return response()->json(['message' => 'ok']);
    }

    public function payout(Request $request, PayDunyaClient $client, PayoutService $payouts): JsonResponse
    {
        if (! $client->isAuthentic($request->input('hash'))) {
            return response()->json(['message' => 'Signature invalide.'], 403);
        }

        $payout = Payout::where('token', $request->input('token'))->first();

        if ($payout !== null) {
            try {
                $payouts->refresh($payout);
            } catch (DomainRuleException) {
                // Nouvelle tentative au prochain rappel de PayDunya.
            }
        }

        return response()->json(['message' => 'ok']);
    }
}
