<?php

use App\Enums\Role;
use App\Enums\TontineType;
use App\Models\Contribution;
use App\Models\Organization;
use App\Models\Tontine;
use App\Models\User;
use App\Services\Otp\OtpSender;
use App\Services\TontineScheduler;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

pest()->extend(TestCase::class)
    ->use(RefreshDatabase::class)
    ->in('Feature');

function memberOf(Organization $organization, Role $role = Role::Member): User
{
    $user = User::factory()->create();
    $organization->memberships()->create(['user_id' => $user->id, 'role' => $role]);

    return $user;
}

function actingAsUser(User $user): User
{
    Sanctum::actingAs($user);

    return $user;
}

/** Remplace l'envoi des SMS et retourne un objet qui capture les codes par numéro. */
function fakeOtpSender(): object
{
    $sender = new class implements OtpSender
    {
        public array $codes = [];

        public function send(string $phone, string $code): void
        {
            $this->codes[$phone] = $code;
        }
    };

    app()->instance(OtpSender::class, $sender);

    return $sender;
}

/**
 * Tontine démarrée : un propriétaire, un trésorier, et deux membres qui cotisent
 * (Awa en position 1, Binta en position 2).
 */
function startedTontine(TontineType $type = TontineType::Rotative, array $shares = []): array
{
    $organization = Organization::factory()->create();
    $owner = memberOf($organization, Role::Owner);
    $treasurer = memberOf($organization, Role::Treasurer);
    $awa = memberOf($organization);
    $binta = memberOf($organization);

    $tontine = Tontine::factory()->for($organization)->create([
        'created_by' => $owner->id,
        'type' => $type,
        'amount' => 5000,
    ]);
    $tontine->addMember($awa, $shares['awa'] ?? 1, 1);
    $tontine->addMember($binta, $shares['binta'] ?? 1, 2);

    app(TontineScheduler::class)->start($tontine);

    return compact('organization', 'owner', 'treasurer', 'awa', 'binta') + ['tontine' => $tontine->refresh()];
}

function tontineUrl(Tontine $tontine, string $path = ''): string
{
    return "/api/v1/orgs/{$tontine->organization_id}/tontines/{$tontine->id}{$path}";
}

function contributionOf(Tontine $tontine, User $user, int $cycle = 1): Contribution
{
    return Contribution::query()
        ->whereHas('cycle', fn ($query) => $query->where('tontine_id', $tontine->id)->where('number', $cycle))
        ->whereHas('member', fn ($query) => $query->where('user_id', $user->id))
        ->firstOrFail();
}

function contributionUrl(Contribution $contribution): string
{
    $cycle = $contribution->cycle;

    return tontineUrl($cycle->tontine, "/cycles/{$cycle->id}/contributions/{$contribution->id}");
}
