<?php

return [

    /*
    |--------------------------------------------------------------------------
    | Cagnottes à gagnants ouvertes à tous
    |--------------------------------------------------------------------------
    |
    | Ouvrir au public une cagnotte où l'on paie un ticket pour gagner une part du pot
    | rapproche l'activité d'une loterie, régulée au Burkina Faso comme ailleurs. Tant que
    | la cagnotte reste dans un cercle privé, l'argument du jeu entre membres tient ;
    | publique, il ne tient plus.
    |
    | Cet interrupteur permet de refermer cette visibilité sans redéployer : les cagnottes
    | à gagnants disparaissent alors de l'annuaire public. Celles déjà lancées restent
    | accessibles par leur lien et à leurs participants : leur argent et leur tirage ne
    | sont pas escamotés en cours de route.
    |
    */

    'public_prize_pools' => (bool) env('PUBLIC_PRIZE_POOLS_ENABLED', true),

];
