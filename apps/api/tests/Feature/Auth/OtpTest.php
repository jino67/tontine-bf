<?php

use App\Mail\OtpCodeMail;
use App\Models\User;
use App\Services\Otp\MailOtpSender;
use App\Services\Otp\OtpSender;
use Illuminate\Support\Facades\Mail;

it('envoie un code puis connecte le membre avec un jeton', function () {
    $sms = fakeOtpSender();

    $this->postJson('/api/v1/auth/otp/request', ['phone' => '70 12 34 56'])->assertAccepted()->assertJsonPath('channel', 'log');

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

it('envoie le code par e-mail et lie l’adresse au compte une fois le code vérifié', function () {
    $mail = fakeOtpSender('mail');

    $this->postJson('/api/v1/auth/otp/request', ['phone' => '70123456'])
        ->assertUnprocessable()
        ->assertJsonValidationErrors('email');

    $this->postJson('/api/v1/auth/otp/request', ['phone' => '70123456', 'email' => ' Awa.Kabore@Example.com '])
        ->assertAccepted()
        ->assertJsonPath('channel', 'mail')
        ->assertJsonPath('destination', 'aw•••@example.com');

    expect($mail->emails['+22670123456'])->toBe('awa.kabore@example.com')
        ->and(User::firstWhere('phone', '+22670123456'))->toBeNull();

    $this->postJson('/api/v1/auth/otp/verify', ['phone' => '70123456', 'code' => $mail->codes['+22670123456']])
        ->assertOk()
        ->assertJsonPath('user.email', 'awa.kabore@example.com');

    expect(User::firstWhere('phone', '+22670123456')->phone_verified_at)->toBeNull();
});

it('envoie toujours le code à l’adresse déjà liée au numéro', function () {
    User::factory()->create(['phone' => '+22670123456', 'email' => 'awa@example.com']);
    $mail = fakeOtpSender('mail');

    $this->postJson('/api/v1/auth/otp/request', ['phone' => '70123456', 'email' => 'autre@example.com'])
        ->assertAccepted()
        ->assertJsonPath('destination', 'aw•••@example.com');

    expect($mail->emails['+22670123456'])->toBe('awa@example.com');

    $this->postJson('/api/v1/auth/otp/verify', ['phone' => '70123456', 'code' => $mail->codes['+22670123456']])
        ->assertOk()
        ->assertJsonPath('user.email', 'awa@example.com');
});

it('rédige en français l’e-mail qui contient le code', function () {
    Mail::fake();
    config(['services.otp.channel' => 'mail']);

    $this->postJson('/api/v1/auth/otp/request', ['phone' => '70123456', 'email' => 'awa@example.com'])->assertAccepted();

    Mail::assertSent(OtpCodeMail::class, fn (OtpCodeMail $mail) => $mail->hasTo('awa@example.com') && preg_match('/^\d{6}$/', $mail->code) === 1);

    (new OtpCodeMail('482913'))
        ->assertHasSubject('Votre code de connexion Tontine BF : 482913')
        ->assertSeeInHtml('482913')
        ->assertSeeInText('valable 10 minutes');
});

it('connecte les numéros de test avec le code fixe, sauf en production', function () {
    $sender = fakeOtpSender('mail');
    config(['services.otp.test_phones' => '70 00 00 01, +226 70000002', 'services.otp.test_code' => '246810']);

    $this->postJson('/api/v1/auth/otp/request', ['phone' => '70000001'])
        ->assertAccepted()
        ->assertJsonPath('channel', 'test');

    expect($sender->codes)->toBe([]);

    $this->postJson('/api/v1/auth/otp/verify', ['phone' => '70000001', 'code' => '246810'])->assertOk();

    app()->detectEnvironment(fn () => 'production');

    $this->postJson('/api/v1/auth/otp/request', ['phone' => '70000002'])
        ->assertUnprocessable()
        ->assertJsonValidationErrors('email');
});

it('n’écrit jamais les codes dans les logs en production', function () {
    app()->detectEnvironment(fn () => 'production');

    config(['services.otp.channel' => 'log']);
    expect(fn () => app(OtpSender::class))->toThrow(RuntimeException::class);

    config(['services.otp.channel' => 'mail']);
    expect(app(OtpSender::class))->toBeInstanceOf(MailOtpSender::class);
});

it('révoque le jeton à la déconnexion', function () {
    $token = User::factory()->create()->createToken('test')->plainTextToken;

    $this->withToken($token)->postJson('/api/v1/auth/logout')->assertNoContent();
    app('auth')->forgetGuards();

    $this->withToken($token)->getJson('/api/v1/me')->assertUnauthorized();
});
