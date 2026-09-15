# Application mobile Tontine BF

Application Flutter des membres et des trésoriers, branchée sur l'API `apps/api`.

## Lancer en local

Démarrer l'API dans un premier terminal :

```bash
cd apps/api && php artisan serve
```

Puis l'application (émulateur Android ou Chrome) :

```bash
cd apps/mobile && flutter run
```

Sans `API_URL`, l'application vise `http://10.0.2.2:8000/api/v1` sur émulateur Android et `http://localhost:8000/api/v1` sur le web. En local, le code de connexion reçu « par SMS » est écrit dans `apps/api/storage/logs/laravel.log`.

Pour viser l'API hébergée chez LWS :

```bash
flutter build apk --release --dart-define=API_URL=https://api.<domaine>/api/v1
```

## Organisation du code

| Dossier | Contenu |
|---|---|
| `lib/app` | Démarrage, thème, charte typographique, navigation principale |
| `lib/core` | Client API, session (jeton chiffré, organisation courante), formats, composants visuels |
| `lib/content` | **Textes fixes** : présentation, guide des types de tontine, FAQ, confidentialité. À modifier ici, sans toucher aux écrans |
| `lib/features/auth` | Présentation, connexion par SMS, nom du membre |
| `lib/features/organizations` | Choix de l'organisation, code d'invitation, membres et rôles |
| `lib/features/home` | Accueil et échéancier personnel |
| `lib/features/tontines` | Liste, création, détail, tours, paiements, tirage vérifiable |
| `lib/features/profile` | Profil, aide, guide, confidentialité, à propos |

Aucune donnée n'est inventée : tout ce qui concerne les tontines, les membres et les cotisations vient de l'API.

## Charte graphique

- **Couleurs** : vert feuille `#1E7A4C` (marque), or `#E0A526` (argent reçu), indigo `#2F3E8F` (tirage), rouge piment `#B83227` (retards), fond coton `#F3F6F1`.
- **Titres** : Young Serif, une seule graisse. La hiérarchie se fait par la taille.
- **Textes, boutons, montants et codes** : Atkinson Hyperlegible, regular et gras, choisie pour sa lisibilité (0 et O, 1 et I bien distincts).
- **Élément signature** : la bande tissée (`WovenBand`), une case par tour, inspirée des rayures du Faso Dan Fani.

Les polices passent par `google_fonts` : elles sont téléchargées au premier lancement puis gardées en cache. Pour les embarquer dans l'APK (utile hors connexion), placer `YoungSerif-Regular.ttf`, `AtkinsonHyperlegible-Regular.ttf` et `AtkinsonHyperlegible-Bold.ttf` dans `assets/google_fonts/`, déclarer ce dossier dans `pubspec.yaml`, puis passer `GoogleFonts.config.allowRuntimeFetching` à `false` dans `main.dart`.

Pour obtenir du gras, utiliser `AppType.sans(bold: true)` et non `copyWith(fontWeight: ...)`, qui produirait un gras artificiel.

## Tests

```bash
flutter analyze && flutter test
```

Le test `draw_verifier_test.dart` vérifie que le téléphone recalcule le tirage exactement comme le serveur.
