<?php

namespace App\Http\Controllers\Api;

use App\Enums\JoinPolicy;
use App\Enums\JoinRequestStatus;
use App\Enums\Role;
use App\Enums\Visibility;
use App\Exceptions\DomainRuleException;
use App\Http\Controllers\Concerns\AuthorizesOrganizationRoles;
use App\Http\Controllers\Controller;
use App\Http\Resources\JoinRequestResource;
use App\Models\JoinRequest;
use App\Models\Organization;
use App\Models\Tontine;
use App\Models\User;
use App\Services\Notifications\NotificationEvents;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Support\Facades\DB;

/**
 * Demandes d'adhésion.
 *
 * Le demandeur n'est pas encore membre : ces routes vivent donc hors du groupe /orgs/{organization},
 * et la vérification se fait sur la visibilité et la règle d'adhésion de l'objet visé.
 */
class JoinRequestController extends Controller
{
    use AuthorizesOrganizationRoles;

    public function __construct(private NotificationEvents $events) {}

    /** Trois refus sur le même objet ferment la porte pendant 30 jours. */
    private const MAX_REFUSALS = 3;

    private const REFUSAL_WINDOW_DAYS = 30;

    public function store(Request $request): JsonResponse
    {
        $data = $request->validate([
            'type' => ['required', 'in:tontine,organisation'],
            'id' => ['required', 'integer'],
            'message' => ['nullable', 'string', 'max:280'],
        ]);

        $user = $request->user();
        [$organization, $tontine] = $this->target($data['type'], (int) $data['id']);
        $policy = $tontine?->join_policy ?? $organization->join_policy;

        if (! $policy->acceptsRequests()) {
            throw new DomainRuleException('Cette page se rejoint uniquement sur invitation.');
        }

        if ($tontine !== null && $tontine->started_at !== null) {
            throw new DomainRuleException('Les inscriptions sont fermées depuis le démarrage.');
        }

        if ($this->alreadyIn($organization, $tontine, $user)) {
            throw new DomainRuleException('Vous en faites déjà partie.');
        }

        $this->ensureNotBlocked($organization, $tontine, $user);

        if ($policy === JoinPolicy::Open) {
            $this->admit($organization, $tontine, $user);

            return response()->json(['status' => JoinRequestStatus::Approved->value], 201);
        }

        $joinRequest = JoinRequest::firstOrCreate(
            [
                'organization_id' => $organization->id,
                'tontine_id' => $tontine?->id,
                'user_id' => $user->id,
                'status' => JoinRequestStatus::Pending,
            ],
            ['message' => $data['message'] ?? null],
        );

        $this->events->joinRequested($joinRequest);

        return JoinRequestResource::make($joinRequest->load(['user', 'tontine', 'organization']))
            ->response()
            ->setStatusCode(201);
    }

    /** Les demandes du membre connecté, pour suivre où il en est. */
    public function mine(Request $request): AnonymousResourceCollection
    {
        return JoinRequestResource::collection(
            JoinRequest::with(['organization', 'tontine', 'user'])
                ->where('user_id', $request->user()->id)
                ->latest('id')
                ->limit(50)
                ->get(),
        );
    }

    public function destroy(Request $request, JoinRequest $joinRequest): JoinRequestResource
    {
        abort_unless($joinRequest->user_id === $request->user()->id, 403, 'Cette demande n’est pas la vôtre.');

        if ($joinRequest->isPending()) {
            $joinRequest->update(['status' => JoinRequestStatus::Withdrawn, 'decided_at' => now()]);
        }

        return JoinRequestResource::make($joinRequest->load(['organization', 'tontine', 'user']));
    }

    /** Côté responsables : les demandes en attente de l'organisation et de ses tontines. */
    public function index(Request $request, Organization $organization): AnonymousResourceCollection
    {
        $this->ensureCanManage($request);

        return JoinRequestResource::collection(
            $organization->joinRequests()->with(['user', 'tontine'])->pending()->latest('id')->get(),
        );
    }

    public function approve(Request $request, Organization $organization, JoinRequest $joinRequest): JoinRequestResource
    {
        $this->ensureCanManage($request);
        $this->ensurePending($joinRequest);

        DB::transaction(function () use ($request, $joinRequest) {
            $this->admit($joinRequest->organization, $joinRequest->tontine, $joinRequest->user);

            $joinRequest->update([
                'status' => JoinRequestStatus::Approved,
                'decided_by' => $request->user()->id,
                'decided_at' => now(),
            ]);
        });

        $this->events->joinAnswered($joinRequest);

        return JoinRequestResource::make($joinRequest->load(['user', 'tontine', 'organization']));
    }

    public function reject(Request $request, Organization $organization, JoinRequest $joinRequest): JoinRequestResource
    {
        $this->ensureCanManage($request);
        $this->ensurePending($joinRequest);

        $data = $request->validate(['reason' => ['nullable', 'string', 'max:280']]);

        $joinRequest->update([
            'status' => JoinRequestStatus::Rejected,
            'decision_reason' => $data['reason'] ?? null,
            'decided_by' => $request->user()->id,
            'decided_at' => now(),
        ]);

        $this->events->joinAnswered($joinRequest);

        return JoinRequestResource::make($joinRequest->load(['user', 'tontine', 'organization']));
    }

    /** @return array{0: Organization, 1: ?Tontine} */
    private function target(string $type, int $id): array
    {
        $shared = [Visibility::Link->value, Visibility::Listed->value];

        if ($type === 'tontine') {
            $tontine = Tontine::whereKey($id)->whereIn('visibility', $shared)->whereNull('hidden_at')->firstOrFail();

            return [$tontine->organization, $tontine];
        }

        return [Organization::whereKey($id)->whereIn('visibility', $shared)->firstOrFail(), null];
    }

    private function alreadyIn(Organization $organization, ?Tontine $tontine, User $user): bool
    {
        return $tontine === null
            ? $organization->memberships()->where('user_id', $user->id)->exists()
            : $tontine->hasMember($user->id);
    }

    private function ensureNotBlocked(Organization $organization, ?Tontine $tontine, User $user): void
    {
        $refusals = JoinRequest::where('user_id', $user->id)
            ->where('organization_id', $organization->id)
            ->where('tontine_id', $tontine?->id)
            ->where('status', JoinRequestStatus::Rejected)
            ->where('decided_at', '>', now()->subDays(self::REFUSAL_WINDOW_DAYS))
            ->count();

        if ($refusals >= self::MAX_REFUSALS) {
            throw new DomainRuleException('Votre demande a déjà été refusée trois fois. Réessayez dans un mois.');
        }
    }

    /** Entrée effective : l'organisation d'abord, la tontine ensuite quand la demande la visait. */
    private function admit(Organization $organization, ?Tontine $tontine, User $user): void
    {
        $organization->memberships()->firstOrCreate(['user_id' => $user->id], ['role' => Role::Member]);

        if ($tontine !== null && ! $tontine->hasMember($user->id)) {
            $tontine->addMember($user);
        }
    }

    private function ensurePending(JoinRequest $joinRequest): void
    {
        if (! $joinRequest->isPending()) {
            throw new DomainRuleException('Cette demande a déjà été traitée.');
        }
    }
}
