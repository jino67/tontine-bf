<?php

namespace App\Console\Commands;

use App\Services\Notifications\ReminderPlanner;
use Illuminate\Console\Command;

/**
 * Prépare les relances du jour.
 *
 * Lancée une fois par jour par le cron de l'hébergement. Relancée deux fois le même jour,
 * elle ne double rien : chaque message porte une empreinte qui l'identifie.
 */
class PlanRemindersCommand extends Command
{
    protected $signature = 'notifications:plan';

    protected $description = 'Prépare les rappels de cotisation et de cagnotte du jour';

    public function handle(ReminderPlanner $planner): int
    {
        $queued = $planner->run();

        $this->info($queued === 0 ? 'Aucun rappel à préparer aujourd’hui.' : "{$queued} rappel(s) mis en file.");

        return self::SUCCESS;
    }
}
