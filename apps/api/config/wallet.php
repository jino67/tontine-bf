<?php

return [

    /*
    |--------------------------------------------------------------------------
    | Dépôt libre
    |--------------------------------------------------------------------------
    |
    | Conserver le solde d'un utilisateur, c'est encaisser des fonds remboursables du public :
    | dans l'UEMOA, cela relève de la BCEAO et demande un agrément, ou un partenariat avec un
    | établissement agréé. Toute l'infrastructure est en place, mais le dépôt libre reste fermé
    | tant que ce cadrage n'est pas écrit. Le reste du portefeuille fonctionne sans lui :
    | un gain, un tour ou un remboursement créditent le solde, qui peut être dépensé ou retiré.
    |
    */

    'deposits_enabled' => (bool) env('WALLET_DEPOSITS_ENABLED', false),

    /*
    |--------------------------------------------------------------------------
    | Plafonds par niveau
    |--------------------------------------------------------------------------
    |
    | 0 : compte neuf, numéro vérifié.
    | 1 : 30 jours d'ancienneté et 3 opérations réussies.
    | 2 : pièce d'identité contrôlée depuis le back-office.
    |
    */

    'levels' => [
        0 => ['balance' => 100000, 'daily_withdrawal' => 50000],
        1 => ['balance' => 500000, 'daily_withdrawal' => 200000],
        2 => ['balance' => 2000000, 'daily_withdrawal' => 500000],
    ],

    'level_one' => ['days' => 30, 'operations' => 3],

    'min_deposit' => 500,

    'min_withdrawal' => 1000,

    /*
    |--------------------------------------------------------------------------
    | Garde-fous
    |--------------------------------------------------------------------------
    |
    | Au-delà de cette cadence, le compte est mis en pause : c'est la signature d'un
    | automate, pas d'une personne qui cotise. Et un premier retrait après changement
    | de numéro attend le délai de sécurité.
    |
    */

    'velocity' => ['operations' => 10, 'minutes' => 10],

    'payout_change_delay_hours' => 24,

];
