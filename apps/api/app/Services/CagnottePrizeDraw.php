<?php

namespace App\Services;

/**
 * Calculs des cagnottes à gagnants, reproduits à l'identique dans l'application pour la vérification.
 *
 * Tickets : « u12#3 » est le 3e ticket du membre 12. Chaque ticket est une chance.
 * Tirage : les tickets sont triés par sha256(graine + "|" + ticket). Les membres sont pris dans l'ordre
 * de leur premier ticket, une seule fois chacun, pour remplir les rangs qui ne sont pas attribués.
 */
final class CagnottePrizeDraw
{
    /** @return array<int, float> pourcentages par rang */
    public static function defaultSplit(int $winners): array
    {
        return match (true) {
            $winners <= 1 => [100.0],
            $winners === 2 => [60.0, 40.0],
            $winners === 3 => [50.0, 30.0, 20.0],
            default => [40.0, 25.0, 15.0, ...array_fill(0, $winners - 3, round(20 / ($winners - 3), 4))],
        };
    }

    public static function isValidSplit(array $split, int $winners): bool
    {
        return count($split) === $winners && $split !== [] && min($split) > 0 && abs(array_sum($split) - 100) < 0.01;
    }

    /** Somme à partager entre les gagnants, après la commission éventuelle de l'organisation. */
    public static function pot(int $collected, int $feePercent): int
    {
        return $collected - intdiv($collected * $feePercent, 100);
    }

    /**
     * Montants entiers par rang. Les francs perdus dans les arrondis vont au 1er rang.
     *
     * @return array<int, int>
     */
    public static function prizeAmounts(int $pot, array $split): array
    {
        $amounts = array_map(fn ($percent) => (int) floor($pot * $percent / 100), $split);

        if ($amounts !== []) {
            $amounts[0] += $pot - array_sum($amounts);
        }

        return $amounts;
    }

    /**
     * Montants des rangs effectivement pourvus. S'il y a moins de gagnants que de rangs,
     * les parts des rangs vides sont réparties au prorata entre les rangs pourvus : tout le pot est distribué.
     *
     * @param  array<int, int>  $ranks  rangs pourvus, dans l'ordre
     * @return array<int, int> montant par rang
     */
    public static function awardedAmounts(int $pot, array $split, array $ranks): array
    {
        if ($ranks === []) {
            return [];
        }

        if (count($ranks) === count($split)) {
            return array_combine($ranks, self::prizeAmounts($pot, array_values($split)));
        }

        $percents = array_map(fn (int $rank) => (float) ($split[$rank - 1] ?? 0), $ranks);
        $total = array_sum($percents);
        $scaled = $total > 0 ? array_map(fn (float $percent) => $percent * 100 / $total, $percents) : $percents;

        return array_combine($ranks, self::prizeAmounts($pot, $scaled));
    }

    /** @return array<int, string> */
    public static function tickets(iterable $contributions): array
    {
        $perUser = [];
        foreach ($contributions as $contribution) {
            $userId = (int) $contribution->user_id;
            $perUser[$userId] = ($perUser[$userId] ?? 0) + (int) $contribution->tickets;
        }

        ksort($perUser);

        $tickets = [];
        foreach ($perUser as $userId => $count) {
            for ($number = 1; $number <= $count; $number++) {
                $tickets[] = "u{$userId}#{$number}";
            }
        }

        return $tickets;
    }

    public static function userOf(string $ticket): int
    {
        return (int) substr(explode('#', $ticket)[0], 1);
    }

    /**
     * @param  array<int, array{rank: int, user_id: int}>  $designations  rangs attribués publiquement
     * @return array<int, array{rank: int, user_id: int, designated: bool}>
     */
    public static function pickWinners(string $seed, array $tickets, array $designations, int $winnersCount): array
    {
        $designated = [];
        foreach ($designations as $designation) {
            $designated[(int) $designation['rank']] = (int) $designation['user_id'];
        }

        $hashes = [];
        foreach ($tickets as $ticket) {
            if (! in_array(self::userOf($ticket), $designated, true)) {
                $hashes[$ticket] = hash('sha256', $seed.'|'.$ticket);
            }
        }

        asort($hashes, SORT_STRING);

        $drawn = [];
        foreach (array_keys($hashes) as $ticket) {
            $userId = self::userOf((string) $ticket);
            if (! in_array($userId, $drawn, true)) {
                $drawn[] = $userId;
            }
        }

        $winners = [];
        for ($rank = 1; $rank <= $winnersCount; $rank++) {
            if (isset($designated[$rank])) {
                $winners[] = ['rank' => $rank, 'user_id' => $designated[$rank], 'designated' => true];
            } elseif ($drawn !== []) {
                $winners[] = ['rank' => $rank, 'user_id' => array_shift($drawn), 'designated' => false];
            }
        }

        return $winners;
    }
}
