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

En local, les codes de connexion ne sont pas envoyés : ils sont écrits dans `storage/logs/laravel.log` (`OTP_CHANNEL=log`).

## Démarrer l'app mobile

Prérequis : Flutter 3.35 ou plus.

```bash
cd apps/mobile && flutter pub get && flutter run
```

L'app mobile est branchée sur la nouvelle API : voir [apps/mobile/README.md](apps/mobile/README.md) pour la configuration, la charte graphique et l'organisation du code.

## Documentation

- [Guide de transformation en SaaS](docs/GUIDE_SAAS.md)
- [Analyse de l'ancien backend PHP](docs/legacy-php.md)
- [Déploiement de l'API sur LWS](docs/deploiement-lws.md)
- [API v1](apps/api/README.md)

## Conventions

- Branches courtes depuis `main` : `feat/...`, `fix/...`, `chore/...`
- Commits au format Conventional Commits : `feat(api): ...`, `fix(mobile): ...`
- Merge par pull request après CI verte
