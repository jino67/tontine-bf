<?php

namespace App\Services\Notifications;

use App\Enums\JoinRequestStatus;
use App\Enums\NotificationType;
use App\Enums\Role;
use App\Models\Cagnotte;
use App\Models\Contribution;
use App\Models\Cycle;
use App\Models\JoinRequest;
use App\Models\Membership;
use App\Models\Tontine;
use App\Models\User;
use App\Models\WalletTransaction;
use Illuminate\Support\Collection;

/**
 * Tous les messages de l'application, écrits à un seul endroit.
 *
 * Les rassembler ici évite que le même événement soit annoncé de trois façons différentes
 * selon l'écran qui le déclenche, et permet de relire d'un coup d'œil ce que l'application
 * dit vraiment à ses membres.
 */
class NotificationEvents
{
    public function __construct(private Notifier $notifier) {}

    /** Le trésorier a enregistré un paiement : le membre est invité à le confirmer. */
    public function contributionRecorded(Contribution $contribution): void
    {
        $contribution->loadMissing(['cycle.tontine', 'member.user']);
        $user = $contribution->member->user;
        $tontine = $contribution->cycle->tontine;

        if ($user === null || $contribution->recorded_by === $user->id) {
            return;
        }

        $this->notifier->queue(
            $user,
            NotificationType::PaymentRecorded,
            "Paiement enregistré : {$tontine->name}",
            "Le trésorier a enregistré {$this->amount($contribution->amount_paid)} pour le tour "
            ."{$contribution->cycle->number}. Confirmez si c’est exact.",
            ['related' => $tontine, 'organization_id' => $tontine->organization_id, 'dedupe' => "paiement_enregistre|contribution:{$contribution->id}"],
        );
    }

    /** Le membre a confirmé : le trésorier et les responsables le savent. */
    public function contributionConfirmed(Contribution $contribution): void
    {
        $contribution->loadMissing(['cycle.tontine', 'member.user']);
        $tontine = $contribution->cycle->tontine;
        $name = $contribution->member->user?->name ?? 'Un membre';

        foreach ($this->responsibles($tontine) as $user) {
            if ($user->id === $contribution->member->user_id) {
                continue;
            }

            $this->notifier->queue(
                $user,
                NotificationType::PaymentConfirmed,
                "Cotisation confirmée : {$tontine->name}",
                "{$name} a confirmé {$this->amount($contribution->amount_paid)} pour le tour {$contribution->cycle->number}.",
                ['related' => $tontine, 'organization_id' => $tontine->organization_id, 'dedupe' => "paiement_confirme|contribution:{$contribution->id}|user:{$user->id}"],
            );
        }
    }

    /** Le tour est complet : le bénéficiaire est prévenu de ce qui lui revient. */
    public function cycleSettledIfComplete(Cycle $cycle): void
    {
        $cycle->loadMissing(['tontine', 'beneficiary.user']);
        $due = (int) $cycle->contributions()->sum('amount_due');
        $paid = (int) $cycle->contributions()->sum('amount_paid');
        $user = $cycle->beneficiary?->user;

        if ($user === null || $due === 0 || $paid < $due) {
            return;
        }

        $this->notifier->queue(
            $user,
            NotificationType::CycleSettled,
            "Votre tour est complet : {$cycle->tontine->name}",
            "Le tour {$cycle->number} est entièrement cotisé : {$this->amount($paid)} vous reviennent.",
            ['related' => $cycle->tontine, 'organization_id' => $cycle->tontine->organization_id, 'dedupe' => "tour_complet|cycle:{$cycle->id}"],
        );
    }

    /** Argent arrivé sur le solde, d'où qu'il vienne. */
    public function walletCredited(User $user, WalletTransaction $transaction): void
    {
        $this->notifier->queue(
            $user,
            NotificationType::WalletCredited,
            'Argent reçu sur votre solde',
            "{$this->amount($transaction->amount)} viennent d’arriver : "
            .strtolower($transaction->type->label()).'. '
            .($transaction->description ?? ''),
            [
                'related' => $transaction,
                'organization_id' => $transaction->organization_id,
                'dedupe' => "solde_credite|wallettransaction:{$transaction->id}",
            ],
        );
    }

    /** Le tirage est révélé : tous les participants l'apprennent, gagnants ou non. */
    public function cagnotteDrawn(Cagnotte $cagnotte): void
    {
        $winners = $cagnotte->winners()->with('user')->get();
        $names = $winners->map(fn ($winner) => $winner->user?->name)->filter()->implode(', ');

        foreach ($this->participants($cagnotte) as $user) {
            $won = $winners->firstWhere('user_id', $user->id);

            $this->notifier->queue(
                $user,
                NotificationType::CagnotteDrawn,
                $won !== null ? "Vous avez gagné : {$cagnotte->title}" : "Tirage de {$cagnotte->title}",
                $won !== null
                    ? "Vous êtes {$this->rank($won->rank)} : {$this->amount($won->prize_amount)} vous reviennent."
                    : ($names === '' ? 'Les gagnants sont connus.' : "Les gagnants sont connus : {$names}."),
                ['related' => $cagnotte, 'organization_id' => $cagnotte->organization_id, 'dedupe' => "cagnotte_tiree|cagnotte:{$cagnotte->id}|user:{$user->id}"],
            );
        }
    }

    /** Une nouvelle édition s'ouvre : ceux qui ont joué la précédente sont prévenus. */
    public function cagnotteRelaunched(Cagnotte $previous, Cagnotte $next): void
    {
        foreach ($this->participants($previous) as $user) {
            $this->notifier->queue(
                $user,
                NotificationType::CagnotteRelaunched,
                "{$next->title} repart : édition {$next->edition}",
                $next->isPrize()
                    ? "Le ticket est à {$this->amount((int) $next->ticket_price)}, jusqu’au "
                    .$next->ends_at->timezone('Africa/Ouagadougou')->locale('fr')->isoFormat('dddd D MMMM')
                    : 'Une nouvelle collecte vient de s’ouvrir.',
                ['related' => $next, 'organization_id' => $next->organization_id, 'dedupe' => "cagnotte_relancee|cagnotte:{$next->id}|user:{$user->id}"],
            );
        }
    }

    /** Quelqu'un demande à entrer : les responsables sont prévenus. */
    public function joinRequested(JoinRequest $joinRequest): void
    {
        $joinRequest->loadMissing(['user', 'tontine', 'organization']);
        $target = $joinRequest->tontine?->name ?? $joinRequest->organization?->name ?? 'votre groupe';
        $name = $joinRequest->user?->name ?? 'Une personne';

        foreach ($this->approvers($joinRequest) as $user) {
            $this->notifier->queue(
                $user,
                NotificationType::JoinRequested,
                'Nouvelle demande d’adhésion',
                "{$name} demande à rejoindre {$target}.",
                ['related' => $joinRequest->tontine ?? $joinRequest->organization, 'organization_id' => $joinRequest->organization_id, 'dedupe' => "demande_adhesion|joinrequest:{$joinRequest->id}|user:{$user->id}"],
            );
        }
    }

    /** La demande est tranchée : le demandeur l'apprend, avec le motif d'un refus. */
    public function joinAnswered(JoinRequest $joinRequest): void
    {
        $joinRequest->loadMissing(['user', 'tontine', 'organization']);
        $user = $joinRequest->user;
        $target = $joinRequest->tontine?->name ?? $joinRequest->organization?->name ?? 'le groupe';
        $approved = $joinRequest->status === JoinRequestStatus::Approved;

        if ($user === null) {
            return;
        }

        $this->notifier->queue(
            $user,
            NotificationType::JoinAnswered,
            $approved ? "Bienvenue dans {$target}" : "Demande refusée : {$target}",
            $approved
                ? 'Votre demande a été acceptée. Vous pouvez maintenant participer.'
                : ($joinRequest->decision_reason ?? 'Votre demande n’a pas été retenue.'),
            ['related' => $joinRequest->tontine ?? $joinRequest->organization, 'organization_id' => $joinRequest->organization_id, 'dedupe' => "demande_tranchee|joinrequest:{$joinRequest->id}"],
        );
    }

    /** @return Collection<int, User> */
    private function participants(Cagnotte $cagnotte): Collection
    {
        return User::whereIn('id', $cagnotte->contributions()->distinct()->pluck('user_id'))->get();
    }

    /** @return Collection<int, User> */
    private function responsibles(Tontine $tontine): Collection
    {
        return Membership::with('user')
            ->where('organization_id', $tontine->organization_id)
            ->get()
            ->filter(fn (Membership $membership) => $membership->role->canRecordContributions())
            ->map(fn (Membership $membership) => $membership->user)
            ->filter()
            ->values();
    }

    /** @return Collection<int, User> */
    private function approvers(JoinRequest $joinRequest): Collection
    {
        return Membership::with('user')
            ->where('organization_id', $joinRequest->organization_id)
            ->get()
            ->filter(fn (Membership $membership) => $membership->role === Role::Owner || $membership->role === Role::Admin)
            ->map(fn (Membership $membership) => $membership->user)
            ->filter()
            ->values();
    }

    private function rank(int $rank): string
    {
        return $rank === 1 ? 'premier' : "{$rank}e";
    }

    private function amount(int $value): string
    {
        return number_format($value, 0, ',', ' ').' FCFA';
    }
}
