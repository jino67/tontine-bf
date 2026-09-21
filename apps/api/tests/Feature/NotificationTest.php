<?php

use App\Enums\NotificationChannel;
use App\Enums\NotificationType;
use App\Enums\PaymentMethod;
use App\Enums\Role;
use App\Mail\NotificationDigestMail;
use App\Models\Cagnotte;
use App\Models\Notification;
use App\Models\NotificationSetting;
use App\Models\Organization;
use App\Models\User;
use App\Services\Notifications\ReminderPlanner;
use Illuminate\Support\Facades\Mail;

/** Place l'échéance du premier tour à un nombre de jours donné, puis prépare les relances. */
function planWithDueIn(array $context, int $days): int
{
    $cycle = $context['tontine']->cycles()->where('number', 1)->firstOrFail();
    $cycle->update(['due_on' => now()->addDays($days)->toDateString()]);

    return app(ReminderPlanner::class)->run();
}

function messagesFor(User $user, ?NotificationType $type = null)
{
    return Notification::where('user_id', $user->id)
        ->when($type !== null, fn ($query) => $query->where('type', $type))
        ->get();
}

it('rappelle trois jours avant, le jour même, puis tous les trois jours', function () {
    $context = startedTontine();
    $awa = $context['awa'];

    planWithDueIn($context, 3);
    expect(messagesFor($awa, NotificationType::ReminderBefore))->toHaveCount(1);

    // Rien la veille : deux messages en deux jours seraient du harcèlement.
    $this->travel(2)->days();
    planWithDueIn($context, 1);
    expect(messagesFor($awa)->count())->toBe(1);

    $this->travel(1)->days();
    planWithDueIn($context, 0);
    expect(messagesFor($awa, NotificationType::ReminderDue))->toHaveCount(1);

    // Deux jours de retard, puis cinq : la relance revient tous les trois jours.
    $this->travel(2)->days();
    planWithDueIn($context, -2);
    $this->travel(1)->days();
    planWithDueIn($context, -3);
    $this->travel(2)->days();
    planWithDueIn($context, -5);

    expect(messagesFor($awa, NotificationType::ReminderLate))->toHaveCount(2);
});

it('annonce le reste à payer, jamais le montant du tour', function () {
    $context = startedTontine();
    $treasurer = actingAsUser($context['treasurer']);
    $contribution = contributionOf($context['tontine'], $context['awa']);

    // Awa a déjà versé 3 000 sur 5 000.
    $this->putJson(contributionUrl($contribution), ['amount_paid' => 3000, 'method' => 'especes'])->assertOk();

    planWithDueIn($context, 0);

    expect(messagesFor($context['awa'], NotificationType::ReminderDue)->first()->body)
        ->toContain('2 000 FCFA')
        ->not->toContain('5 000 FCFA');

    // Binta, qui n'a rien versé, est relancée sur la totalité.
    expect(messagesFor($context['binta'], NotificationType::ReminderDue)->first()->body)->toContain('5 000 FCFA');
});

it('ne relance pas un membre qui a réglé sa cotisation', function () {
    $context = startedTontine();
    $contribution = contributionOf($context['tontine'], $context['awa']);

    actingAsUser($context['treasurer']);
    $this->putJson(contributionUrl($contribution), ['amount_paid' => 5000, 'method' => 'especes'])->assertOk();

    planWithDueIn($context, 0);

    expect(messagesFor($context['awa'], NotificationType::ReminderDue))->toHaveCount(0)
        ->and(messagesFor($context['binta'], NotificationType::ReminderDue))->toHaveCount(1);
});

it('attend le matin pour ce qui tombe la nuit', function () {
    $context = startedTontine();

    // 2 h du matin à Ouagadougou : le rappel est mis en file pour 7 h.
    $this->travelTo(now()->timezone('Africa/Ouagadougou')->setTime(2, 0)->utc());
    planWithDueIn($context, 0);

    $message = messagesFor($context['awa'], NotificationType::ReminderDue)->first();

    expect($message->send_after)->not->toBeNull()
        ->and($message->send_after->timezone('Africa/Ouagadougou')->hour)->toBe(7)
        // Rien ne part avant l'heure.
        ->and(Notification::query()->due()->count())->toBe(0);
});

it('n’envoie pas deux fois le même message dans la journée', function () {
    $context = startedTontine();

    planWithDueIn($context, 0);
    planWithDueIn($context, 0);
    planWithDueIn($context, 0);

    expect(messagesFor($context['awa'], NotificationType::ReminderDue))->toHaveCount(1);
});

it('laisse couper les relances d’une tontine sans couper les autres', function () {
    $context = startedTontine();
    $awa = actingAsUser($context['awa']);
    $tontine = $context['tontine'];

    $this->putJson('/api/v1/notifications/settings', ['muted' => ["tontine:{$tontine->id}"]])
        ->assertOk()
        ->assertJsonPath('data.muted.0', "tontine:{$tontine->id}");

    planWithDueIn($context, 0);

    expect(messagesFor($awa, NotificationType::ReminderDue))->toHaveCount(0)
        // Binta, qui n'a rien coupé, reçoit la sienne.
        ->and(messagesFor($context['binta'], NotificationType::ReminderDue))->toHaveCount(1);

    // Tout couper d'un coup est possible aussi.
    $this->putJson('/api/v1/notifications/settings', ['reminders' => false, 'muted' => []])->assertOk();
    expect(NotificationSetting::forUser($awa)->reminders)->toBeFalse();
});

it('récapitule les retards pour le trésorier et les responsables', function () {
    $context = startedTontine();

    $this->travel(2)->days();
    planWithDueIn($context, -2);

    $digest = messagesFor($context['treasurer'], NotificationType::TreasurerDigest)->first();

    expect($digest)->not->toBeNull()
        ->and($digest->body)->toContain('2 membres')
        ->and($digest->body)->toContain('10 000 FCFA')
        ->and(messagesFor($context['owner'], NotificationType::TreasurerDigest))->toHaveCount(1);
});

it('regroupe les messages d’un membre en un seul e-mail', function () {
    Mail::fake();
    $awa = User::factory()->create(['name' => 'Awa', 'email' => 'awa@exemple.bf']);

    // Deux messages qui visent l'e-mail.
    foreach ([1, 2] as $index) {
        Notification::create([
            'user_id' => $awa->id,
            'type' => NotificationType::TreasurerDigest,
            'channel' => NotificationChannel::Mail,
            'title' => "Retards {$index}",
            'body' => 'Il reste des cotisations à recevoir.',
            'dedupe_key' => "test-{$index}",
        ]);
    }

    $this->artisan('notifications:send')->assertSuccessful();

    Mail::assertSentCount(1);
    Mail::assertSent(NotificationDigestMail::class, fn ($mail) => $mail->notifications->count() === 2
        && $mail->hasTo('awa@exemple.bf'));

    expect(Notification::where('status', Notification::SENT)->count())->toBe(2);
});

it('prévient le membre quand le trésorier enregistre, et le trésorier quand le membre confirme', function () {
    $context = startedTontine();
    $contribution = contributionOf($context['tontine'], $context['awa']);

    actingAsUser($context['treasurer']);
    $this->putJson(contributionUrl($contribution), ['amount_paid' => 5000, 'method' => 'especes'])->assertOk();

    expect(messagesFor($context['awa'], NotificationType::PaymentRecorded)->first()?->body)
        ->toContain('5 000 FCFA')
        ->toContain('Confirmez');

    actingAsUser($context['awa']);
    $this->postJson(contributionUrl($contribution).'/confirm')->assertOk();

    expect(messagesFor($context['treasurer'], NotificationType::PaymentConfirmed))->toHaveCount(1);
});

it('prévient les participants du tirage, puis de la nouvelle édition', function () {
    $organization = Organization::factory()->create();
    $admin = actingAsUser(memberOf($organization, Role::Admin));
    $player = memberOf($organization);

    $cagnotte = publicCagnotte($organization, $admin, ['recurring' => true, 'duration' => 'flash_24h']);
    addContribution($cagnotte, $player, 5000, PaymentMethod::PayDunya);
    $cagnotte->update(['ends_at' => now()->subMinute()]);

    $url = "/api/v1/orgs/{$organization->id}/cagnottes/{$cagnotte->id}";
    $this->postJson($url.'/draw', ['reveal_after' => now()->addSecond()->toIso8601String()])->assertOk();
    $this->travel(2)->seconds();
    $this->postJson($url.'/draw/reveal')->assertOk();

    expect(messagesFor($player, NotificationType::CagnotteDrawn)->first()?->title)->toContain('Vous avez gagné')
        ->and(messagesFor($player, NotificationType::CagnotteRelaunched)->first()?->title)->toContain('édition 2')
        // Le gain versé sur le solde le dit aussi.
        ->and(Cagnotte::where('series_id', $cagnotte->id)->count())->toBe(1);
});

it('liste les messages reçus et les marque lus', function () {
    $awa = actingAsUser(User::factory()->create());
    $message = Notification::create([
        'user_id' => $awa->id,
        'type' => NotificationType::ReminderDue,
        'title' => 'C’est aujourd’hui',
        'body' => '5 000 FCFA pour le tour 1.',
        'dedupe_key' => 'test-lecture',
    ]);

    $this->getJson('/api/v1/notifications')
        ->assertOk()
        ->assertJsonPath('data.0.title', 'C’est aujourd’hui')
        ->assertJsonPath('data.0.read', false)
        ->assertJsonPath('meta.unread', 1);

    $this->postJson("/api/v1/notifications/{$message->id}/read")->assertOk()->assertJsonPath('data.read', true);
    $this->getJson('/api/v1/notifications')->assertJsonPath('meta.unread', 0);

    // Le message d'un autre membre reste hors de portée.
    actingAsUser(User::factory()->create());
    $this->postJson("/api/v1/notifications/{$message->id}/read")->assertForbidden();
});
