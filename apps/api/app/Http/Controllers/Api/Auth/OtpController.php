<?php

namespace App\Http\Controllers\Api\Auth;

use App\Http\Controllers\Controller;
use App\Http\Requests\Auth\RequestOtpRequest;
use App\Http\Requests\Auth\VerifyOtpRequest;
use App\Http\Resources\UserResource;
use App\Services\Otp\OtpService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Response;

class OtpController extends Controller
{
    public function sendCode(RequestOtpRequest $request, OtpService $otp): JsonResponse
    {
        $delivery = $otp->send($request->validated('phone'), $request->validated('email'));
        $destination = $delivery['destination'] === null ? null : self::maskEmail($delivery['destination']);

        return response()->json([
            'message' => match ($delivery['channel']) {
                'mail' => "Un code de connexion a été envoyé à {$destination}.",
                'test' => 'Numéro de test : saisissez le code de test.',
                default => 'Un code de connexion a été envoyé.',
            },
            'channel' => $delivery['channel'],
            'destination' => $destination,
        ], 202);
    }

    public function verifyCode(VerifyOtpRequest $request, OtpService $otp): JsonResponse
    {
        $user = $otp->verify($request->validated('phone'), $request->validated('code'));
        $token = $user->createToken($request->validated('device_name') ?? 'mobile')->plainTextToken;

        return response()->json([
            'token' => $token,
            'user' => UserResource::make($user),
        ]);
    }

    public function logout(Request $request): Response
    {
        $request->user()->currentAccessToken()->delete();

        return response()->noContent();
    }

    /** « awa.kabore@gmail.com » devient « aw•••@gmail.com » : de quoi reconnaître son adresse sans la révéler. */
    private static function maskEmail(string $email): string
    {
        [$local, $domain] = array_pad(explode('@', $email, 2), 2, '');

        return mb_substr($local, 0, min(2, max(1, mb_strlen($local) - 1))).'•••@'.$domain;
    }
}
