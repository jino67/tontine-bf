# Déploiement de l'API sur LWS

L'API (`apps/api`) est hébergée chez LWS **à la racine d'un domaine**, sans sous-domaine, par exemple `goaicorp-crm.online`. La base est **SQLite** : un seul fichier, rien à créer dans le panneau. L'application mobile est compilée avec l'adresse de cette API.

Deux méthodes sont décrites : l'archive prête à décompresser (sans SSH, section 2) et le dépôt Git (avec SSH, section 8).

## 0. Vérifier ce que permet l'offre LWS

| Besoin | Utilité | Si l'offre ne le permet pas |
|---|---|---|
| PHP 8.2 ou plus | Laravel 12 | changer la version PHP dans le panneau, sinon changer d'offre |
| Extension `pdo_sqlite` | base de données | activer l'extension, sinon passer à MySQL ou MariaDB (section 6) |
| Tâches planifiées (cron) toutes les minutes | file d'attente, purge des codes SMS et des jetons | sans cron, les purges doivent être lancées à la main |
| Certificat SSL Let's Encrypt | HTTPS, obligatoire pour l'app et pour PayDunya | l'activer sur le domaine |
| Accès SSH | pratique, mais **pas nécessaire** avec l'archive | utiliser la méthode de la section 2 |

Le code est testé en CI sur SQLite, MariaDB 10.11 et MySQL 8.0.

## 1. Structure installée

Le dossier du domaine (`htdocs/<domaine>`) contient :

```
index.php          point d'entrée, il charge tontine-api/
.htaccess          réécriture des adresses vers index.php
favicon.ico
robots.txt
tontine-api/       l'application Laravel complète, avec son .env et sa base SQLite
```

C'est le même montage qu'amicalclinic et sunset-tour. L'application est **à l'intérieur** du dossier web, puisqu'il n'y a pas de sous-domaine dont on choisirait le dossier racine. Elle est protégée trois fois : le `.htaccess` racine refuse `tontine-api/` (`RewriteRule ^tontine-api/ - [F,L]`), il refuse aussi partout les fichiers `.env`, `.sqlite`, `.log` et `.zip`, et `tontine-api/.htaccess` refuse tout accès direct. C'est la vérification la plus importante après l'installation.

Les deux fichiers de la racine, `index.php` et `.htaccess`, sont dans [`apps/api/deploy/lws/`](../apps/api/deploy/lws/). Ils remplacent ceux de `public/`, qui ne partent pas en ligne.

## 2. Installation par archive (sans SSH)

Construire l'archive depuis le poste de développement :

```bash
cd apps/api && composer install --no-dev --optimize-autoloader
```

Puis reproduire la structure ci-dessus : à la racine, `favicon.ico` et `robots.txt` de `public/` avec `index.php` et `.htaccess` de `apps/api/deploy/lws/` ; le reste du projet dans `tontine-api/`. Créer la base avec `php artisan migrate --force` avant de compresser, pour n'avoir rien à lancer sur le serveur.

Sur le panneau LWS : ouvrir `htdocs/<domaine>`, bouton « Charger » pour envoyer l'archive, la sélectionner, bouton « Extraire », puis supprimer l'archive.

Vérifier ensuite dans le navigateur :

| Adresse | Résultat attendu |
|---|---|
| `https://<domaine>/up` | page « Application up » |
| `https://<domaine>/tontine-api/.env` | erreur 403 |
| `https://<domaine>/api/v1/orgs` | message « Unauthenticated » |

Si une erreur 500 apparaît, donner les droits d'écriture (755, ou 775 si LWS l'exige) à `tontine-api/storage` et `tontine-api/database`.

**Si la racine affiche la page LWS « Bravo ! Votre domaine a bien été créé » et `/up` une 404 LWS**, les fichiers ne sont pas en cause : le domaine ne pointe pas sur le serveur de l'hébergement. Comparer l'adresse du domaine avec celle d'un domaine qui fonctionne sur le même hébergement :

```bash
nslookup <domaine>
```

Si les adresses diffèrent, dans le panneau LWS du domaine : faire pointer les enregistrements A de `@` et `www` sur l'adresse de l'hébergement, et rattacher le domaine à l'hébergement sur le dossier `htdocs/<domaine>` (comme les autres domaines déjà en ligne). La propagation DNS prend de quelques minutes à quelques heures.

## 3. Fichier `.env` de production

```dotenv
APP_NAME="Tontine BF"
APP_ENV=staging
APP_KEY=base64:<généré par php artisan key:generate --show>
APP_DEBUG=false
APP_URL=https://<domaine>
APP_LOCALE=fr

LOG_CHANNEL=daily
LOG_LEVEL=warning

# SQLite : le fichier tontine-api/database/database.sqlite
DB_CONNECTION=sqlite

SESSION_DRIVER=file
CACHE_STORE=file
QUEUE_CONNECTION=database

PAYDUNYA_MODE=live
PAYDUNYA_MASTER_KEY=<clé principale>
PAYDUNYA_PUBLIC_KEY=<clé publique live>
PAYDUNYA_PRIVATE_KEY=<clé privée live>
PAYDUNYA_TOKEN=<token live>
PAYDUNYA_STORE_NAME="Tontine BF"
PAYDUNYA_PAYOUTS_ENABLED=false
```

**`APP_ENV=staging` tant qu'aucun fournisseur SMS n'est branché** : les codes de connexion sont alors écrits dans `tontine-api/storage/logs`, sinon personne ne peut se connecter. En `production`, l'API refuse d'envoyer un code tant qu'un fournisseur SMS n'est pas configuré.

## 4. Tâche cron

Dans le panneau LWS, une tâche **toutes les minutes** :

```bash
cd /home/<utilisateur>/htdocs/<domaine>/tontine-api && php artisan schedule:run >> /dev/null 2>&1
```

Le chemin de `php` en ligne de commande peut différer de la version du site : vérifier avec `php -v` et utiliser le chemin complet de la bonne version si besoin. Le planificateur (`routes/console.php`) traite la file d'attente chaque minute, puis purge chaque jour les codes OTP périmés et les jetons expirés.

## 5. PayDunya

- Les clés de production ne vivent que dans `tontine-api/.env`. Si une clé privée ou un token a circulé (capture d'écran, message), le régénérer dans PayDunya avant l'ouverture au public.
- `APP_URL` doit être l'adresse publique en `https` : elle sert à construire les adresses envoyées à PayDunya.
- Adresses appelées par PayDunya, laissées accessibles sans authentification : `https://<domaine>/api/v1/payments/paydunya/ipn` et `https://<domaine>/api/v1/payouts/paydunya/callback`. Leur signature est vérifiée, puis le statut est relu auprès de PayDunya.
- La page `https://<domaine>/paiement/retour` s'affiche au membre après son paiement.
- Il n'existe pas de sandbox pour les remises : un essai de remise déplace de l'argent réel. Garder `PAYDUNYA_PAYOUTS_ENABLED=false` jusqu'au premier essai maîtrisé.

## 6. Base de données

La base est le fichier `tontine-api/database/database.sqlite`. Le sauvegarder, c'est le télécharger depuis le gestionnaire de fichiers : à faire régulièrement, c'est toute la base. Activer aussi les sauvegardes proposées par LWS.

SQLite convient au démarrage : peu de membres, peu d'écritures simultanées. Quand le trafic augmente, créer une base MySQL ou MariaDB dans le panneau, remplacer les lignes `DB_` du `.env` par `DB_CONNECTION=mariadb` et les identifiants fournis, puis relancer `php artisan migrate --force`. Le code ne change pas.

## 7. Sécurité et exploitation

- `APP_DEBUG=false` en production, sans exception : sinon les erreurs affichent la configuration.
- Vérifier après chaque mise à jour que `https://<domaine>/tontine-api/.env` répond 403.
- Surveiller `https://<domaine>/up` avec un service de disponibilité (UptimeRobot, Better Stack...).
- Les journaux sont dans `tontine-api/storage/logs`.
- Passer sur un VPS LWS quand les volumes augmentent (SMS en masse, notifications de paiement) : on pourra alors utiliser Redis, Horizon et un worker permanent.

## 8. Variante avec SSH et Git

Si l'offre donne un accès SSH, le dépôt peut être cloné hors du dossier web et `index.php` adapté en conséquence :

```bash
git clone --branch main https://github.com/jino67/tontine-bf.git ~/tontine-bf
```

```bash
cd ~/tontine-bf/apps/api && composer install --no-dev --optimize-autoloader && php artisan migrate --force && php artisan optimize
```

Mise à jour :

```bash
cd ~/tontine-bf && php apps/api/artisan down && git pull --ff-only
```

```bash
cd ~/tontine-bf/apps/api && composer install --no-dev --optimize-autoloader && php artisan migrate --force && php artisan optimize && php artisan up
```

Toujours déployer une version taguée qui a passé la CI, jamais une branche en cours.

## 9. Mise à jour de l'installation par archive

Remplacer le contenu de `tontine-api`, **sauf** `tontine-api/.env` et `tontine-api/database/database.sqlite`, puis vider `tontine-api/bootstrap/cache` (supprimer les fichiers `.php` qui s'y trouvent) pour que la configuration soit relue.

## 10. Compiler l'application mobile

```bash
flutter build apk --release --dart-define=API_URL=https://<domaine>/api/v1
```

Sans `API_URL`, l'app vise l'API locale de développement (`http://10.0.2.2:8000/api/v1` sur émulateur Android, `http://localhost:8000/api/v1` sur le web).
