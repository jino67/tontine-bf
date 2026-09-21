<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\CagnotteResource;
use App\Http\Resources\PaymentResource;
use App\Http\Resources\WalletTransactionResource;
use App\Models\Cagnotte;
use App\Services\PaymentService;
use App\Services\Wallet\WalletService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * Cagnottes ouvertes à tous : n'importe quel compte peut les voir et y participer,
 * sans appartenir à l'organisation qui les porte.
 *
 * Participer n'est pas adhérer : c'est un paiement, il n'y a donc rien à approuver.
 * La liste des participants et les montants de chacun ne sortent jamais d'ici :
 * un visiteur voit la somme réunie, les gains possibles et le tirage, rien d'autre.
 */
class PublicCagnotteController extends Controller
{
    public function __construct(private PaymentService $payments, private WalletService $wallet) {}

    public function show(Cagnotte $cagnotte): CagnotteResource
    {
        return CagnotteResource::make($this->visible($cagnotte));
    }

    /** Participation payée depuis le compte mobile money du participant. */
    public function pay(Request $request, Cagnotte $cagnotte): JsonResponse
    {
        $cagnotte = $this->visible($cagnotte);
        $amount = $this->amount($request, $cagnotte);

        $payment = $this->payments->startForCagnotte($cagnotte, $request->user(), $amount);

        return PaymentResource::make($payment)->response()->setStatusCode(201);
    }

    /** Participation réglée depuis le solde. */
    public function payWithBalance(Request $request, Cagnotte $cagnotte): JsonResponse
    {
        $cagnotte = $this->visible($cagnotte);
        $amount = $this->amount($request, $cagnotte);

        $transaction = $this->wallet->participate($cagnotte, $request->user(), $amount);

        return WalletTransactionResource::make($transaction)->response()->setStatusCode(201);
    }

    /** Montant de la participation, au moins le minimum fixé par la cagnotte. */
    private function amount(Request $request, Cagnotte $cagnotte): int
    {
        $data = $request->validate([
            'amount' => ['required', 'integer', 'min:'.max(1, $cagnotte->min_amount), 'max:10000000'],
        ]);

        return (int) $data['amount'];
    }

    /**
     * Une cagnotte restée privée, ou masquée par des signalements, répond 404 : le visiteur
     * n'a pas à apprendre son existence. Un lien vers une édition passée mène à l'édition ouverte.
     */
    private function visible(Cagnotte $cagnotte): Cagnotte
    {
        $current = $cagnotte->currentEdition();

        abort_if($current->hidden_at !== null || ! $current->visibility->isShared(), 404);

        return Cagnotte::whereKey($current->id)
            ->withTotals()
            ->with(['organization', 'winners' => fn ($winners) => $winners->orderBy('rank'), 'winners.user'])
            ->firstOrFail();
    }
}
