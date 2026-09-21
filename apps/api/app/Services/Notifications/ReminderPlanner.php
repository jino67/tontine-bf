<?php

namespace App\Services\Notifications;

use App\Enums\CagnotteStatus;
use App\Enums\NotificationType;
use App\Models\Cagnotte;
use App\Models\Contribution;
use App\Models\Membership;
use App\Models\Tontine;
use App\Models\User;
use Illuminate\Support\Collection;

/**
 * Relances de cotisation et rappels de cagnotte, préparés une fois par jour.
 *
 * Deux principes : rien n'est envoyé à qui a déjà payé, et le message porte le reste à payer,
 * pas le montant du tour. Un membre qui a versé la moitié n'a pas à lire qu'il doit tout.
 * Le ton change aussi avec le retard : neutre avant l'échéance, ferme après, jamais
 * culpabilisant — un message blessant finit en capture d'écran dans le groupe WhatsApp.
 */
class ReminderPlanner
{
    /** Après l'échéance : deux jours, puis tous les trois jours. */
    private const FIRST_LATE_DAY = 2;

    private const LATE_INTERVAL = 3;

    public function __construct(private Notifier $notifier) {}

    public function run(): int
    {
        return $this->contributionReminders() + $this->treasurerDigests() + $this->cagnotteReminders();
    }

    /** Rappels adressés aux membres qui doivent encore quelque chose. */
    private function contributionReminders(): int
    {
        $queued = 0;

        foreach ($this->openContributions() as $contribution) {
            $cycle = $contribution->cycle;
            $type = $this->typeFor((int) $cycle->due_on->startOfDay()->diffInDays(now()->startOfDay(), false));

            if ($type === null) {
                continue;
            }

            $user = $contribution->member->user;
            $tontine = $cycle->tontine;
            $left = $contribution->amount_due - $contribution->amount_paid;

            $queued += $this->notifier->queue(
                $user,
                $type,
                $this->title($type, $tontine),
                $this->body($type, $left, $cycle->number, $tontine->name, $cycle->due_on),
                ['related' => $tontine, 'organization_id' => $tontine->organization_id],
            ) === null ? 0 : 1;
        }

        return $queued;
    }

    /** Un récapitulatif par tontine en retard, adressé au trésorier et aux responsables. */
    private function treasurerDigests(): int
    {
        $queued = 0;

        $late = $this->openContributions()
            ->filter(fn (Contribution $contribution) => $contribution->cycle->due_on->startOfDay()->isBefore(now()->startOfDay()))
            ->groupBy(fn (Contribution $contribution) => $contribution->cycle->tontine_id);

        foreach ($late as $tontineId => $contributions) {
            $tontine = Tontine::find($tontineId);

            if ($tontine === null) {
                continue;
            }

            $total = $contributions->sum(fn (Contribution $contribution) => $contribution->amount_due - $contribution->amount_paid);
            $count = $contributions->count();
            $body = $count === 1
                ? "Un membre n’a pas terminé sa cotisation : il reste {$this->amount($total)} à recevoir."
                : "{$count} membres n’ont pas terminé leur cotisation : il reste {$this->amount($total)} à recevoir.";

            foreach ($this->responsibles($tontine) as $user) {
                $queued += $this->notifier->queue(
                    $user,
                    NotificationType::TreasurerDigest,
                    "Retards sur {$tontine->name}",
                    $body,
                    ['related' => $tontine, 'organization_id' => $tontine->organization_id],
                ) === null ? 0 : 1;
            }
        }

        return $queued;
    }

    /** Vingt-quatre heures avant la clôture, pour les membres qui n'ont pas encore participé. */
    private function cagnotteReminders(): int
    {
        $queued = 0;

        $closing = Cagnotte::query()
            ->where('status', CagnotteStatus::Open)
            ->whereBetween('ends_at', [now(), now()->addDay()])
            ->get();

        foreach ($closing as $cagnotte) {
            $participants = $cagnotte->contributions()->pluck('user_id')->all();

            $members = User::query()
                ->whereHas('memberships', fn ($query) => $query->where('organization_id', $cagnotte->organization_id))
                ->whereNotIn('id', $participants)
                ->get();

            foreach ($members as $user) {
                $queued += $this->notifier->queue(
                    $user,
                    NotificationType::CagnotteClosing,
                    "Il reste un jour pour {$cagnotte->title}",
                    $cagnotte->isPrize()
                        ? "Le ticket est à {$this->amount((int) $cagnotte->ticket_price)}. Le tirage suit la clôture."
                        : "La collecte se termine demain. Participation à partir de {$this->amount($cagnotte->min_amount)}.",
                    ['related' => $cagnotte, 'organization_id' => $cagnotte->organization_id],
                ) === null ? 0 : 1;
            }
        }

        return $queued;
    }

    /** @return Collection<int, Contribution> */
    private function openContributions(): Collection
    {
        return Contribution::query()
            ->with(['cycle.tontine', 'member.user'])
            ->whereNull('confirmed_at')
            ->whereColumn('amount_paid', '<', 'amount_due')
            ->whereHas('cycle', fn ($query) => $query->whereBetween('due_on', [now()->subMonths(2), now()->addDays(3)]))
            ->whereHas('cycle.tontine', fn ($query) => $query->whereNotNull('started_at'))
            ->get();
    }

    /** Rien n'est envoyé entre l'échéance passée et le deuxième jour de retard : laissons respirer. */
    private function typeFor(int $daysLate): ?NotificationType
    {
        if ($daysLate === -3) {
            return NotificationType::ReminderBefore;
        }

        if ($daysLate === 0) {
            return NotificationType::ReminderDue;
        }

        if ($daysLate >= self::FIRST_LATE_DAY && ($daysLate - self::FIRST_LATE_DAY) % self::LATE_INTERVAL === 0) {
            return NotificationType::ReminderLate;
        }

        return null;
    }

    private function title(NotificationType $type, Tontine $tontine): string
    {
        return match ($type) {
            NotificationType::ReminderBefore => "Cotisation à venir : {$tontine->name}",
            NotificationType::ReminderDue => "C’est aujourd’hui : {$tontine->name}",
            default => "Cotisation en retard : {$tontine->name}",
        };
    }

    private function body(NotificationType $type, int $left, int $cycleNumber, string $name, $dueOn): string
    {
        $amount = $this->amount($left);
        $day = $dueOn->locale('fr')->isoFormat('dddd D MMMM');

        return match ($type) {
            NotificationType::ReminderBefore => "Votre cotisation de {$amount} pour le tour {$cycleNumber} est attendue {$day}.",
            NotificationType::ReminderDue => "C’est aujourd’hui : {$amount} pour le tour {$cycleNumber} de {$name}.",
            default => "Votre cotisation du tour {$cycleNumber} attend depuis le {$day} : {$amount} restent à verser.",
        };
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

    private function amount(int $value): string
    {
        return number_format($value, 0, ',', ' ').' FCFA';
    }
}
