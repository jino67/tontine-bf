<?php

namespace App\Services;

use App\Enums\TontineStatus;
use App\Enums\TontineType;
use App\Exceptions\DomainRuleException;
use App\Models\Draw;
use App\Models\Tontine;
use App\Models\TontineMember;
use App\Models\User;
use Carbon\CarbonInterface;
use Illuminate\Support\Facades\DB;

/**
 * Tirage en deux temps : l'empreinte de la graine est publiée à l'engagement,
 * la graine n'est révélée qu'après la date annoncée. Personne ne peut choisir le résultat.
 */
class DrawService
{
    public function commit(Tontine $tontine, User $author, CarbonInterface $revealAfter): Draw
    {
        return DB::transaction(function () use ($tontine, $author, $revealAfter) {
            $tontine = Tontine::whereKey($tontine->id)->lockForUpdate()->firstOrFail();

            if ($tontine->type !== TontineType::DrawOrder) {
                throw new DomainRuleException('Le tirage ne concerne que les tontines de type tirage_ordre.');
            }

            if ($tontine->status !== TontineStatus::Active) {
                throw new DomainRuleException('Démarrez la tontine avant de lancer le tirage.');
            }

            if ($tontine->draw()->exists()) {
                throw new DomainRuleException('Le tirage de cette tontine a déjà été lancé.');
            }

            $slots = $tontine->members()->orderBy('id')->get()
                ->flatMap(fn (TontineMember $member) => array_map(
                    fn (int $share) => "{$member->id}#{$share}",
                    range(1, $member->shares),
                ))
                ->values()
                ->all();

            $seed = bin2hex(random_bytes(32));

            return $tontine->draw()->create([
                'organization_id' => $tontine->organization_id,
                'created_by' => $author->id,
                'seed' => $seed,
                'seed_hash' => hash('sha256', $seed),
                'slots' => $slots,
                'reveal_after' => $revealAfter,
            ]);
        });
    }

    public function reveal(Draw $draw): Draw
    {
        return DB::transaction(function () use ($draw) {
            $draw = Draw::whereKey($draw->id)->lockForUpdate()->firstOrFail();

            if ($draw->isRevealed()) {
                throw new DomainRuleException('Ce tirage a déjà été révélé.');
            }

            if (now()->lt($draw->reveal_after)) {
                $date = $draw->reveal_after->timezone('Africa/Ouagadougou')->format('d/m/Y à H:i');
                throw new DomainRuleException("Le tirage ne peut pas être révélé avant le {$date}.");
            }

            $result = self::order($draw->seed, $draw->slots);
            $cycles = $draw->tontine->cycles()->orderBy('number')->get();

            if ($cycles->count() !== count($result)) {
                throw new DomainRuleException('Le nombre de cycles ne correspond pas au nombre de parts tirées.');
            }

            foreach ($cycles as $index => $cycle) {
                $cycle->update(['beneficiary_member_id' => (int) explode('#', $result[$index])[0]]);
            }

            $draw->update(['result' => $result, 'revealed_at' => now()]);

            return $draw;
        });
    }

    /** Ordre de passage : parts triées par sha256(graine + "|" + part). Recalculable par n'importe quel membre. */
    public static function order(string $seed, array $slots): array
    {
        $hashes = [];

        foreach ($slots as $slot) {
            $hashes[$slot] = hash('sha256', $seed.'|'.$slot);
        }

        asort($hashes, SORT_STRING);

        return array_map('strval', array_keys($hashes));
    }
}
