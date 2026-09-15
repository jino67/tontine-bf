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
        $otp->send($request->validated('phone'));

        return response()->json(['message' => 'Un code de connexion a été envoyé par SMS.'], 202);
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
}
