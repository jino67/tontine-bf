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
 * la graine n'est révélée qu'après la date annoncée.
 *
 * Le responsable peut attribuer lui-même certains tours. Ces attributions sont publiées
 * en même temps que l'empreinte et ne peuvent plus changer ; seuls les autres tours sont tirés au sort.
 */
class DrawService
{
    /**
     * @param  array<int, array{cycle: int, member_id: int}>  $designations
     */
    public function commit(Tontine $tontine, User $author, CarbonInterface $revealAfter, array $designations = []): Draw
    {
        return DB::transaction(function () use ($tontine, $author, $revealAfter, $designations) {
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

            [$slots, $assigned] = self::assign($slots, $designations, $tontine->cycles()->count());
            $seed = bin2hex(random_bytes(32));

            return $tontine->draw()->create([
                'organization_id' => $tontine->organization_id,
                'created_by' => $author->id,
                'seed' => $seed,
                'seed_hash' => hash('sha256', $seed),
                'slots' => $slots,
                'designations' => $assigned,
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

            $cycles = $draw->tontine->cycles()->orderBy('number')->get();
            $designations = $draw->designations ?? [];

            if ($cycles->count() !== count($draw->slots) + count($designations)) {
                throw new DomainRuleException('Le nombre de cycles ne correspond pas au nombre de parts.');
            }

            $result = self::merge($designations, self::order($draw->seed, $draw->slots), $cycles->count());

            foreach ($cycles as $index => $cycle) {
                $cycle->update(['beneficiary_member_id' => (int) explode('#', $result[$index])[0]]);
            }

            $draw->update(['result' => $result, 'revealed_at' => now()]);

            return $draw;
        });
    }

    /** Parts tirées au sort : triées par sha256(graine + "|" + part). Recalculable par n'importe quel membre. */
    public static function order(string $seed, array $slots): array
    {
        $hashes = [];

        foreach ($slots as $slot) {
            $hashes[$slot] = hash('sha256', $seed.'|'.$slot);
        }

        asort($hashes, SORT_STRING);

        return array_map('strval', array_keys($hashes));
    }

    /**
     * Ordre final : les tours attribués gardent leur part, les autres reçoivent les parts tirées dans l'ordre.
     *
     * @param  array<int, array{cycle: int, slot: string}>  $designations
     */
    public static function merge(array $designations, array $drawn, int $cyclesCount): array
    {
        $byCycle = [];
        foreach ($designations as $designation) {
            $byCycle[(int) $designation['cycle']] = (string) $designation['slot'];
        }

        $result = [];
        for ($cycle = 1; $cycle <= $cyclesCount; $cycle++) {
            $result[] = $byCycle[$cycle] ?? array_shift($drawn);
        }

        return $result;
    }

    /**
     * Retire des parts à tirer celles qui sont attribuées par le responsable.
     *
     * @return array{0: array<int, string>, 1: array<int, array{cycle: int, slot: string}>}
     */
    private static function assign(array $slots, array $designations, int $cyclesCount): array
    {
        $assigned = [];

        foreach ($designations as $designation) {
            $cycle = (int) $designation['cycle'];
            $memberId = (int) $designation['member_id'];

            if ($cycle < 1 || $cycle > $cyclesCount || isset($assigned[$cycle])) {
                throw new DomainRuleException("Le tour {$cycle} ne peut pas être attribué.");
            }

            $slot = null;
            foreach ($slots as $candidate) {
                if ((int) explode('#', $candidate)[0] === $memberId) {
                    $slot = $candidate;
                    break;
                }
            }

            if ($slot === null) {
                throw new DomainRuleException('Ce membre n’a plus de part disponible : chaque part ne reçoit qu’un tour.');
            }

            $slots = array_values(array_diff($slots, [$slot]));
            $assigned[$cycle] = $slot;
        }

        ksort($assigned);

        return [
            $slots,
            array_map(fn (int $cycle, string $slot) => ['cycle' => $cycle, 'slot' => $slot], array_keys($assigned), $assigned),
        ];
    }
}
