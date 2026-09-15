# Tontine BF

Plateforme SaaS de gestion de tontines et d'épargne communautaire pour les organisations (associations, groupements, coopératives, comités d'entreprise, IMF).

## Structure du dépôt

| Dossier | Contenu |
|---|---|
| `apps/api` | API Laravel 12 (Sanctum, multi-organisations) |
| `apps/mobile` | Application Flutter des membres |
| `docs` | Guide SaaS, analyse de l'ancien backend, décisions d'architecture |
| `.github/workflows` | Intégration continue de chaque application |

L'état du projet avant la restructuration est conservé sous le tag `legacy-flutter-php`.

## Démarrer l'API

Prérequis : PHP 8.2 ou plus, Composer, extension `pdo_sqlite`.

```bash
cd apps/api
```

```bash
composer install
```

```bash
cp .env.example .env && php artisan key:generate && php artisan migrate
```

```bash
php artisan test
```

En local, les codes OTP ne sont pas envoyés par SMS : ils sont écrits dans `storage/logs/laravel.log`.

## Démarrer l'app mobile

Prérequis : Flutter 3.35 ou plus.

```bash
cd apps/mobile && flutter pub get && flutter run
```

L'app mobile appelle encore l'ancien backend PHP. Son branchement sur la nouvelle API fait l'objet de la phase 2 du [guide](docs/GUIDE_SAAS.md).

## Documentation

- [Guide de transformation en SaaS](docs/GUIDE_SAAS.md)
- [Analyse de l'ancien backend PHP](docs/legacy-php.md)
- [API v1](apps/api/README.md)

## Conventions

- Branches courtes depuis `main` : `feat/...`, `fix/...`, `chore/...`
- Commits au format Conventional Commits : `feat(api): ...`, `fix(mobile): ...`
- Merge par pull request après CI verte
