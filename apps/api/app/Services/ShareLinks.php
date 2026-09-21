<?php

namespace App\Services;

use App\Enums\JoinRequestStatus;
use App\Enums\Visibility;
use App\Models\Cagnotte;
use App\Models\Invitation;
use App\Models\JoinRequest;
use App\Models\Organization;
use App\Models\Tontine;
use App\Models\User;
use Illuminate\Database\Eloquent\Builder;

/**
 * Résout un code partagé en fiche publique.
 *
 * Règle tenue partout dans ce fichier : aucun numéro de téléphone, aucune adresse e-mail,
 * aucune liste nominative de membres, aucun montant individuel.
 */
class ShareLinks
{
    /**
     * @param  User|null  $viewer  visiteur connecté, pour savoir s'il est déjà membre ou s'il a une demande en cours
     * @return array{type: string, data: array<string, mixed>}|null
     */
    public static function resolve(string $code, ?User $viewer = null): ?array
    {
        $code = strtoupper(trim($code));

        if ($code === '') {
            return null;
        }

        if (($invitation = Invitation::with(['organization', 'tontine'])->where('code', $code)->first()) !== null) {
            return ['type' => 'invitation', 'data' => self::invitation($invitation)];
        }

        $tontines = Tontine::with(['organization', 'creator'])->withCount('members')->whereNull('hidden_at');
        if (($tontine = self::shared($tontines, $code)) !== null) {
            return ['type' => 'tontine', 'data' => self::tontine($tontine) + self::viewer($viewer, $tontine->organization, $tontine)];
        }

        $cagnottes = Cagnotte::with('organization')->withCount('contributions')->whereNull('hidden_at');
        if (($cagnotte = self::shared($cagnottes, $code)) !== null) {
            return ['type' => 'cagnotte', 'data' => self::cagnotte($cagnotte) + self::viewer($viewer, $cagnotte->organization, null)];
        }

        if (($organization = self::shared(Organization::withCount('memberships'), $code)) !== null) {
            return ['type' => 'organisation', 'data' => self::organization($organization) + self::viewer($viewer, $organization, null)];
        }

        return null;
    }

    /** @return array<string, mixed> */
    public static function tontine(Tontine $tontine): array
    {
        return [
            'id' => $tontine->id,
            'name' => $tontine->name,
            'type' => $tontine->type->value,
            'amount' => $tontine->amount,
            'frequency' => $tontine->frequency->value,
            'starts_on' => $tontine->starts_on->toDateString(),
            'status' => $tontine->status->value,
            'members_count' => $tontine->members_count,
            'max_members' => $tontine->max_members,
            'places_left' => $tontine->max_members === null
                ? null
                : max(0, $tontine->max_members - (int) $tontine->members_count),
            'started' => $tontine->started_at !== null,
            'join_policy' => $tontine->join_policy->value,
            'accepts_requests' => $tontine->started_at === null && $tontine->join_policy->acceptsRequests(),
            'organization' => self::organizationName($tontine->organization),
            'creator' => $tontine->creator?->name,
            'share_url' => $tontine->shareUrl(),
        ];
    }

    /** @return array<string, mixed> */
    public static function cagnotte(Cagnotte $cagnotte): array
    {
        $status = $cagnotte->effectiveStatus();

        return [
            'id' => $cagnotte->id,
            'title' => $cagnotte->title,
            'description' => $cagnotte->description,
            'mode' => $cagnotte->mode->value,
            'status' => $status->value,
            'ends_at' => $cagnotte->ends_at->toIso8601String(),
            'seconds_left' => (int) max(0, ceil(now()->diffInSeconds($cagnotte->ends_at, false))),
            'collected_amount' => $cagnotte->collectedAmount(),
            'target_amount' => $cagnotte->target_amount,
            'min_amount' => $cagnotte->min_amount,
            'ticket_price' => $cagnotte->ticket_price,
            'winners_count' => $cagnotte->winners_count,
            'fee_percent' => $cagnotte->fee_percent,
            'contributions_count' => $cagnotte->contributions_count,
            'organization' => self::organizationName($cagnotte->organization),
            'share_url' => $cagnotte->shareUrl(),
        ];
    }

    /** @return array<string, mixed> */
    public static function organization(Organization $organization): array
    {
        return [
            'id' => $organization->id,
            'name' => $organization->name,
            'members_count' => $organization->memberships_count,
            'join_policy' => $organization->join_policy->value,
            'accepts_requests' => $organization->join_policy->acceptsRequests(),
            'share_url' => $organization->shareUrl(),
        ];
    }

    /** @return array<string, mixed> */
    private static function invitation(Invitation $invitation): array
    {
        return [
            'code' => $invitation->code,
            'usable' => $invitation->isUsable(),
            'expires_at' => $invitation->expires_at?->toIso8601String(),
            'organization' => $invitation->organization->name,
            'tontine' => $invitation->tontine?->name,
        ];
    }

    /** Ce que le visiteur connecté peut faire : rien de personnel sur les autres, seulement sur lui-même. */
    private static function viewer(?User $user, ?Organization $organization, ?Tontine $tontine): array
    {
        if ($user === null) {
            return [];
        }

        $isMember = $tontine !== null
            ? $tontine->hasMember($user->id)
            : ($organization?->memberships()->where('user_id', $user->id)->exists() ?? false);

        $pending = JoinRequest::where('user_id', $user->id)
            ->where('organization_id', $organization?->id)
            ->where('tontine_id', $tontine?->id)
            ->where('status', JoinRequestStatus::Pending)
            ->exists();

        return ['viewer' => ['is_member' => $isMember, 'has_pending_request' => $pending]];
    }

    /** Le nom d'une organisation restée privée n'apparaît pas sur une fiche publique. */
    private static function organizationName(?Organization $organization): ?string
    {
        return $organization !== null && $organization->visibility->isShared() ? $organization->name : null;
    }

    /** @param  Builder<covariant \Illuminate\Database\Eloquent\Model>  $query */
    private static function shared(Builder $query, string $code): mixed
    {
        return $query->where('share_code', $code)
            ->whereIn('visibility', [Visibility::Link->value, Visibility::Listed->value])
            ->first();
    }
}
