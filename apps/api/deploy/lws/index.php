<?php

/*
|--------------------------------------------------------------------------
| Point d'entree de l'API chez LWS (hebergement mutualise)
|--------------------------------------------------------------------------
|
| Meme montage qu'amicalclinic : le dossier du domaine sert de dossier
| public, et l'API Laravel complete vit dans le sous-dossier tontine-api/,
| que le .htaccess voisin interdit au web.
|
|   htdocs/<domaine>/
|     .htaccess   index.php   favicon.ico   robots.txt
|     tontine-api/   app, vendor, storage, database, .env : jamais servi
|
| Ce fichier remplace public/index.php du depot, qui ne part pas en ligne.
*/

use Illuminate\Foundation\Application;
use Illuminate\Http\Request;

define('LARAVEL_START', microtime(true));

if (file_exists($maintenance = __DIR__.'/tontine-api/storage/framework/maintenance.php')) {
    require $maintenance;
}

require __DIR__.'/tontine-api/vendor/autoload.php';

/** @var Application $app */
$app = require_once __DIR__.'/tontine-api/bootstrap/app.php';

// La racine du domaine EST le dossier public.
$app->usePublicPath(__DIR__);

$app->handleRequest(Request::capture());
