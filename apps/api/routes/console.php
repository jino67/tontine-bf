<?php

use Illuminate\Support\Facades\Schedule;

// Sur l'hébergement LWS, un cron lance schedule:run chaque minute (voir docs/deploiement-lws.md).
// Il remplace un worker permanent : la file d'attente est vidée à chaque passage.
Schedule::command('queue:work --stop-when-empty --max-time=50')->everyMinute()->withoutOverlapping();

Schedule::command('model:prune')->daily();
Schedule::command('sanctum:prune-expired --hours=24')->daily();
