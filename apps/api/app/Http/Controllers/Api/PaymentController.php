<?php

namespace App\Http\Controllers\Api;

use App\Exceptions\DomainRuleException;
use App\Http\Controllers\Concerns\AuthorizesOrganizationRoles;
use App\Http\Controllers\Controller;
use App\Http\Resources\PaymentResource;
use App\Http\Resources\WalletTransactionResource;
use App\Models\Cagnotte;
use App\Models\Contribution;
use App\Models\Cycle;
use App\Models\Organization;
use App\Models\Payment;
use App\Models\Tontine;
use App\Services\PaymentService;
use App\Services\Wallet\WalletService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/** Le membre paie lui-même en ligne ; l'application ouvre ensuite checkout_url. */
class PaymentController extends Controller
{
    use AuthorizesOrganizationRoles;

    public function __construct(private PaymentService $payments, private WalletService $wallet) {}

    public function payContribution(Request $request, Organization $organization, Tontine $tontine, Cycle $cycle, Contribution $contribution): JsonResponse
    {
        abort_unless(
            $contribution->member->user_id === $request->user()->id,
            403,
            'Seul le membre concerné peut payer sa cotisation en ligne.',
        );

        $payment = $this->payments->startForContribution($contribution, $request->user());

        return PaymentResource::make($payment)->response()->setStatusCode(201);
    }

    /** Même cotisation, réglée avec l'argent déjà présent sur le solde. */
    public function payContributionFromBalance(Request $request, Organization $organization, Tontine $tontine, Cycle $cycle, Contribution $contribution): JsonResponse
    {
        abort_unless(
            $contribution->member->user_id === $request->user()->id,
            403,
            'Seul le membre concerné peut payer sa cotisation.',
        );

        $transaction = $this->wallet->payContribution($contribution, $request->user());

        return WalletTransactionResource::make($transaction)->response()->setStatusCode(201);
    }

    public function payCagnotteFromBalance(Request $request, Organization $organization, Cagnotte $cagnotte): JsonResponse
    {
        $data = $request->validate([
            'amount' => ['required', 'integer', 'min:'.$cagnotte->min_amount, 'max:10000000'],
        ]);

        $transaction = $this->wallet->participate($cagnotte, $request->user(), (int) $data['amount']);

        return WalletTransactionResource::make($transaction)->response()->setStatusCode(201);
    }

    public function payCagnotte(Request $request, Organization $organization, Cagnotte $cagnotte): JsonResponse
    {
        $data = $request->validate([
            'amount' => ['required', 'integer', 'min:'.$cagnotte->min_amount, 'max:10000000'],
        ]);

        $payment = $this->payments->startForCagnotte($cagnotte, $request->user(), (int) $data['amount']);

        return PaymentResource::make($payment)->response()->setStatusCode(201);
    }

    /** Suivi d'un paiement par celui qui l'a lancé, y compris hors de toute organisation. */
    public function mine(Request $request, Payment $payment): PaymentResource
    {
        abort_unless($payment->user_id === $request->user()->id, 403, 'Ce paiement ne vous concerne pas.');

        return PaymentResource::make($this->refreshed($payment));
    }

    /** Relit le statut auprès de PayDunya : utile au retour dans l'application, même sans notification. */
    public function show(Request $request, Organization $organization, Payment $payment): PaymentResource
    {
        abort_unless(
            $payment->user_id === $request->user()->id || $this->membership($request)->role->canRecordContributions(),
            403,
            'Ce paiement ne vous concerne pas.',
        );

        return PaymentResource::make($this->refreshed($payment));
    }

    private function refreshed(Payment $payment): Payment
    {
        try {
            return $this->payments->refresh($payment);
        } catch (DomainRuleException) {
            // PayDunya injoignable : on renvoie le dernier statut connu, le téléphone réessaiera.
            return $payment;
        }
    }
}
