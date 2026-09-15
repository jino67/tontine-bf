<?php

namespace App\Services;

use App\Enums\TontineStatus;
use App\Enums\TontineType;
use App\Exceptions\DomainRuleException;
use App\Models\Contribution;
use App\Models\Tontine;
use App\Models\TontineMember;
use Illuminate\Support\Facades\DB;

class TontineScheduler
{
    /** Clôt les inscriptions, génère les cycles et les cotisations attendues de chaque membre. */
    public function start(Tontine $tontine): void
    {
        DB::transaction(function () use ($tontine) {
            $tontine = Tontine::whereKey($tontine->id)->lockForUpdate()->firstOrFail();

            if ($tontine->status !== TontineStatus::Draft) {
                throw new DomainRuleException('Cette tontine a déjà démarré.');
            }

            $members = $tontine->members()
                ->orderByRaw('position is null')
                ->orderBy('position')
                ->orderBy('id')
                ->get();

            $minimum = $tontine->type->minMembers();

            if ($members->count() < $minimum) {
                throw new DomainRuleException("Il faut au moins {$minimum} membres pour démarrer cette tontine.");
            }

            // Une part = un tour de bénéficiaire : un membre à 2 parts reçoit la cagnotte 2 fois.
            $slots = $members->flatMap(fn (TontineMember $member) => array_fill(0, $member->shares, $member))->values();
            $cyclesCount = $tontine->type->hasBeneficiaries() ? $slots->count() : $tontine->cycles_count;
            $now = now();

            for ($index = 0; $index < $cyclesCount; $index++) {
                $cycle = $tontine->cycles()->create([
                    'organization_id' => $tontine->organization_id,
                    'number' => $index + 1,
                    'due_on' => $tontine->frequency->dueDate($tontine->starts_on, $index)->toDateString(),
                    // Pour « tirage_ordre », les bénéficiaires sont fixés par le tirage vérifiable.
                    'beneficiary_member_id' => $tontine->type === TontineType::Rotative ? $slots[$index]->id : null,
                ]);

                $rows = $members->map(fn (TontineMember $member) => [
                    'organization_id' => $tontine->organization_id,
                    'cycle_id' => $cycle->id,
                    'tontine_member_id' => $member->id,
                    'amount_due' => $tontine->amount * $member->shares,
                    'amount_paid' => 0,
                    'created_at' => $now,
                    'updated_at' => $now,
                ])->all();

                foreach (array_chunk($rows, 200) as $chunk) {
                    Contribution::insert($chunk);
                }
            }

            $tontine->update([
                'status' => TontineStatus::Active,
                'cycles_count' => $cyclesCount,
                'started_at' => $now,
            ]);
        });
    }
}
