<?php

namespace App\Http\Controllers\Api;

use App\Exceptions\DomainRuleException;
use App\Http\Controllers\Controller;
use App\Http\Resources\WalletTransactionResource;
use App\Models\User;
use App\Services\Otp\OtpService;
use App\Services\PayoutService;
use App\Services\Wallet\WalletService;
use App\Support\PhoneNumber;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Validation\Rule;

/**
 * Solde, historique, transfert entre membres et numéro de retrait.
 *
 * Le dépôt et le retrait ont leurs propres contrôleurs : ce sont les deux seuls endroits
 * où l'argent entre et sort réellement de l'application.
 */
class WalletController extends Controller
{
    public function __construct(private WalletService $wallet) {}

    public function show(Request $request): JsonResponse
    {
        return response()->json(['data' => $this->wallet->summary($request->user())]);
    }

    public function transactions(Request $request): AnonymousResourceCollection
    {
        return WalletTransactionResource::collection($this->wallet->history($request->user()));
    }

    public function transfer(Request $request): JsonResponse
    {
        $data = $request->validate([
            'phone' => ['required', 'string', 'max:20'],
            'amount' => ['required', 'integer', 'min:100', 'max:10000000'],
            'note' => ['nullable', 'string', 'max:120'],
        ]);

        $phone = PhoneNumber::normalize($data['phone']);
        $recipient = $phone === null ? null : User::where('phone', $phone)->first();

        if ($recipient === null) {
            throw new DomainRuleException('Aucun membre ne correspond à ce numéro. Invitez-le d’abord.');
        }

        $transaction = $this->wallet->transfer($request->user(), $recipient, (int) $data['amount'], $data['note'] ?? null);

        return WalletTransactionResource::make($transaction)->response()->setStatusCode(201);
    }

    /**
     * Numéro de retrait. Le changer demande un code de connexion : c'est la porte de sortie
     * de l'argent, et elle ne s'ouvre pas sur la seule possession d'un téléphone déverrouillé.
     */
    public function payoutPhone(Request $request, OtpService $otp): JsonResponse
    {
        $data = $request->validate([
            'phone' => ['required', 'string', 'max:20'],
            'withdraw_mode' => ['required', Rule::in(PayoutService::WITHDRAW_MODES)],
            'code' => ['nullable', 'string', 'size:6'],
        ]);

        $user = $request->user();
        $phone = PhoneNumber::normalize($data['phone']);

        if ($phone === null) {
            throw new DomainRuleException('Ce numéro n’est pas un numéro burkinabè valide.');
        }

        if (($data['code'] ?? null) === null) {
            $sent = $otp->send($user->phone);

            return response()->json([
                'message' => 'Un code vous a été envoyé pour confirmer ce numéro de retrait.',
                'channel' => $sent['channel'],
            ], 202);
        }

        $otp->verify($user->phone, $data['code']);

        $user->update([
            'payout_phone' => $phone,
            'payout_mode' => $data['withdraw_mode'],
            'payout_changed_at' => now(),
        ]);

        return response()->json(['data' => $this->wallet->summary($user->refresh())]);
    }
}
