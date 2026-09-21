<?php

use Illuminate\Support\Facades\Schedule;

// Sur l'hébergement LWS, un cron lance schedule:run chaque minute (voir docs/deploiement-lws.md).
// Il remplace un worker permanent : la file d'attente est vidée à chaque passage.
Schedule::command('queue:work --stop-when-empty --max-time=50')->everyMinute()->withoutOverlapping();

// Relances du jour, préparées tôt le matin à Ouagadougou, puis envoyées par paquets.
Schedule::command('notifications:plan')->dailyAt('06:30')->timezone('Africa/Ouagadougou');
Schedule::command('notifications:send')->everyFifteenMinutes()->withoutOverlapping();

Schedule::command('model:prune')->daily();
Schedule::command('sanctum:prune-expired --hours=24')->daily();
