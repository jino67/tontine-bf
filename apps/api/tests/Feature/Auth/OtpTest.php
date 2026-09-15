<?php

use App\Models\User;

it('envoie un code par SMS puis connecte le membre avec un jeton', function () {
    $sms = fakeOtpSender();

    $this->postJson('/api/v1/auth/otp/request', ['phone' => '70 12 34 56'])->assertAccepted();

    $token = $this->postJson('/api/v1/auth/otp/verify', [
        'phone' => '+22670123456',
        'code' => $sms->codes['+22670123456'],
        'device_name' => 'Tecno Spark 20',
    ])->assertOk()->assertJsonPath('user.phone', '+22670123456')->json('token');

    $this->withToken($token)->getJson('/api/v1/me')->assertOk()->assertJsonPath('data.phone', '+22670123456');

    expect(User::firstWhere('phone', '+22670123456')->phone_verified_at)->not->toBeNull();
});

it("refuse un numéro qui n'est pas burkinabè", function () {
    fakeOtpSender();

    $this->postJson('/api/v1/auth/otp/request', ['phone' => '+33612345678'])
        ->assertUnprocessable()
        ->assertJsonValidationErrors('phone');
});

it("n'accepte un code qu'une seule fois", function () {
    $sms = fakeOtpSender();
    $this->postJson('/api/v1/auth/otp/request', ['phone' => '70123456']);
    $payload = ['phone' => '70123456', 'code' => $sms->codes['+22670123456']];

    $this->postJson('/api/v1/auth/otp/verify', $payload)->assertOk();
    $this->postJson('/api/v1/auth/otp/verify', $payload)->assertUnprocessable();
});

it('refuse un code expiré', function () {
    $sms = fakeOtpSender();
    $this->postJson('/api/v1/auth/otp/request', ['phone' => '70123456']);

    $this->travel(11)->minutes();

    $this->postJson('/api/v1/auth/otp/verify', ['phone' => '70123456', 'code' => $sms->codes['+22670123456']])
        ->assertUnprocessable()
        ->assertJsonValidationErrors('code');
});

it('invalide le code après 5 essais erronés', function () {
    $sms = fakeOtpSender();
    $this->postJson('/api/v1/auth/otp/request', ['phone' => '70123456']);
    $code = $sms->codes['+22670123456'];
    $wrong = $code === '000000' ? '111111' : '000000';

    foreach (range(1, 5) as $attempt) {
        $this->postJson('/api/v1/auth/otp/verify', ['phone' => '70123456', 'code' => $wrong])->assertUnprocessable();
    }

    $this->postJson('/api/v1/auth/otp/verify', ['phone' => '70123456', 'code' => $code])->assertUnprocessable();
});

it('limite les demandes de code à 3 par numéro sur 10 minutes', function () {
    fakeOtpSender();

    foreach (range(1, 3) as $attempt) {
        $this->postJson('/api/v1/auth/otp/request', ['phone' => '70123456'])->assertAccepted();
    }

    $this->postJson('/api/v1/auth/otp/request', ['phone' => '70123456'])->assertTooManyRequests();
});

it('révoque le jeton à la déconnexion', function () {
    $token = User::factory()->create()->createToken('test')->plainTextToken;

    $this->withToken($token)->postJson('/api/v1/auth/logout')->assertNoContent();
    app('auth')->forgetGuards();

    $this->withToken($token)->getJson('/api/v1/me')->assertUnauthorized();
});
