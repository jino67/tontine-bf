# Déploiement de l'API sur LWS

L'API (`apps/api`) est hébergée chez LWS sur un sous-domaine, par exemple `api.<domaine>`. L'application mobile est compilée avec l'adresse de cette API.

## 0. Vérifier ce que permet l'offre LWS

La procédure dépend de l'offre souscrite. À vérifier dans l'espace client LWS avant de commencer :

| Besoin | Utilité | Si l'offre ne le permet pas |
|---|---|---|
| PHP 8.2 ou plus | Laravel 12 | changer la version PHP dans le panneau, sinon changer d'offre |
| Accès SSH | `composer install`, migrations, cache | **bloquant** : prendre une offre avec SSH ou un VPS LWS |
| Tâches planifiées (cron) toutes les minutes | planificateur Laravel, file d'attente, purges | **bloquant** |
| Sous-domaine avec dossier racine au choix | faire pointer `api.<domaine>` sur `public/` | règle `.htaccess` de repli (section 6) |
| Base MySQL ou MariaDB | données | noter le moteur exact : il sert pour `DB_CONNECTION` |
| Certificat SSL Let's Encrypt | HTTPS, obligatoire pour l'app | l'activer sur le sous-domaine |

Le code est testé en CI sur SQLite, MariaDB 10.11 et MySQL 8.0.

## 1. Préparer l'hébergement

1. Créer une base de données et son utilisateur dans le panneau LWS. Noter l'hôte, le nom de la base, l'utilisateur et le mot de passe.
2. Créer le sous-domaine `api.<domaine>` avec pour dossier racine `tontine-bf/apps/api/public`.
3. Activer le certificat SSL du sous-domaine.
4. Choisir PHP 8.2 ou plus pour ce sous-domaine, avec les extensions `pdo_mysql`, `mbstring`, `openssl`, `intl`, `fileinfo`, `tokenizer`, `xml` et `ctype`.
5. Pour un environnement de test, répéter l'opération avec `api-staging.<domaine>` et une base séparée.

## 2. Premier déploiement (SSH)

Se connecter en SSH puis cloner le dépôt dans le dossier personnel. Si le dépôt passe en privé, ajouter d'abord une clé de déploiement en lecture seule dans GitHub.

```bash
git clone --branch main https://github.com/jino67/tontine-bf.git ~/tontine-bf
```

```bash
cd ~/tontine-bf/apps/api && composer install --no-dev --optimize-autoloader
```

Si `composer` n'est pas disponible sur le serveur, télécharger `composer.phar` depuis getcomposer.org et lancer `php composer.phar install --no-dev --optimize-autoloader`.

```bash
cp .env.example .env && php artisan key:generate
```

Modifier ensuite `.env` avec les valeurs de production :

```dotenv
APP_NAME="Tontine BF"
APP_ENV=production
APP_DEBUG=false
APP_URL=https://api.<domaine>
APP_LOCALE=fr

LOG_CHANNEL=daily
LOG_LEVEL=warning

# mariadb ou mysql, selon le moteur indiqué par LWS
DB_CONNECTION=mariadb
DB_HOST=<hôte fourni par LWS>
DB_PORT=3306
DB_DATABASE=<nom de la base>
DB_USERNAME=<utilisateur>
DB_PASSWORD=<mot de passe>

SESSION_DRIVER=database
CACHE_STORE=database
QUEUE_CONNECTION=database
```

**Important** : en `APP_ENV=production`, l'API refuse d'envoyer les codes OTP tant qu'aucun fournisseur SMS n'est branché. Personne ne peut donc se connecter. Pour tester sur LWS avant cette intégration, utiliser `APP_ENV=staging` : les codes sont alors écrits dans `storage/logs`.

Créer les tables et mettre en cache la configuration :

```bash
php artisan migrate --force && php artisan optimize
```

Vérifier que l'API répond (code 200 attendu) :

```bash
curl -I https://api.<domaine>/up
```

## 3. Tâche cron

Dans le panneau LWS, ajouter une tâche exécutée **toutes les minutes** :

```bash
cd ~/tontine-bf/apps/api && php artisan schedule:run >> /dev/null 2>&1
```

Le chemin de `php` en ligne de commande peut différer de la version choisie pour le site. Vérifier avec `php -v` en SSH et utiliser le chemin complet de la bonne version si besoin.

Le planificateur (`routes/console.php`) traite la file d'attente chaque minute, puis purge chaque jour les codes OTP périmés et les jetons expirés. Sur un hébergement mutualisé, il n'y a ni Redis ni processus permanent : c'est ce cron qui remplace un worker.

## 4. Mettre à jour

```bash
cd ~/tontine-bf && php apps/api/artisan down && git pull --ff-only
```

```bash
cd ~/tontine-bf/apps/api && composer install --no-dev --optimize-autoloader && php artisan migrate --force && php artisan optimize && php artisan up
```

Toujours déployer une version taguée qui a passé la CI, jamais une branche en cours.

## 5. Sécurité et exploitation

- `APP_DEBUG=false` en production, sans exception : sinon les erreurs affichent la configuration.
- Le fichier `.env` reste hors de `public/` : c'est pour cela que le sous-domaine pointe sur `apps/api/public` et non sur la racine du dépôt.
- Activer les sauvegardes proposées par LWS et exporter aussi la base chaque jour hors de LWS.
- Surveiller `https://api.<domaine>/up` avec un service de disponibilité (UptimeRobot, Better Stack...).
- Les journaux sont dans `apps/api/storage/logs`.
- Passer sur un VPS LWS quand les volumes augmentent (SMS en masse, webhooks de paiement) : on pourra alors utiliser Redis, Horizon et un worker permanent.

## 6. Repli si le dossier racine du sous-domaine ne peut pas être choisi

Placer ce fichier `.htaccess` à la racine du sous-domaine pour rediriger vers `apps/api/public` :

```apache
RewriteEngine On
RewriteRule ^(.*)$ tontine-bf/apps/api/public/$1 [L]
```

Cette solution fonctionne, mais un dossier racine pointant directement sur `public/` reste préférable.

## 7. Compiler l'application mobile

```bash
flutter build apk --release --dart-define=API_URL=https://api.<domaine>/api/v1
```

Sans `API_URL`, l'app vise l'API locale de développement (`http://10.0.2.2:8000/api/v1` sur émulateur Android, `http://localhost:8000/api/v1` sur le web).
