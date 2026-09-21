<?php

namespace App\Http\Controllers\Api;

use App\Exceptions\DomainRuleException;
use App\Http\Controllers\Concerns\AuthorizesOrganizationRoles;
use App\Http\Controllers\Controller;
use App\Http\Resources\WalletTransactionResource;
use App\Models\Cycle;
use App\Models\Organization;
use App\Models\Tontine;
use App\Services\Wallet\WalletService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * Versement du tour au bénéficiaire, sur son solde.
 *
 * Ne verse que ce que l'organisation détient réellement dans l'application : les cotisations
 * remises en espèces au trésorier n'ont jamais transité par ici, et se remettent de la main
 * à la main comme avant.
 */
class CyclePayoutController extends Controller
{
    use AuthorizesOrganizationRoles;

    public function __construct(private WalletService $wallet) {}

    public function __invoke(Request $request, Organization $organization, Tontine $tontine, Cycle $cycle): JsonResponse
    {
        $this->ensureCanRecord($request);

        $beneficiary = $cycle->beneficiary?->user;

        if ($beneficiary === null) {
            throw new DomainRuleException('Ce tour n’a pas encore de bénéficiaire.');
        }

        $transaction = $this->wallet->payCycle($cycle, $beneficiary);

        return WalletTransactionResource::make($transaction)->response()->setStatusCode(201);
    }
}
