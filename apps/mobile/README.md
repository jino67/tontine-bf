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

Sans `API_URL`, l'application vise `http://10.0.2.2:8000/api/v1` sur émulateur Android et `http://localhost:8000/api/v1` sur le web. En local, le code de connexion est écrit dans `apps/api/storage/logs/laravel.log` (API en `OTP_CHANNEL=log`).

Pour viser l'API hébergée chez LWS, installée à la racine d'un domaine (sans sous-domaine) :

```bash
flutter build apk --release --dart-define=API_URL=https://<domaine>/api/v1
```

## Organisation du code

| Dossier | Contenu |
|---|---|
| `lib/app` | Démarrage, thème, charte typographique, navigation principale |
| `lib/core` | Client API, session (jeton chiffré, organisation courante), formats, composants visuels |
| `lib/content` | **Textes fixes** : présentation, guide des types de tontine, FAQ, confidentialité. À modifier ici, sans toucher aux écrans |
| `lib/features/auth` | Présentation, connexion par code (par e-mail pendant les essais), nom du membre |
| `lib/features/organizations` | Choix de l'organisation, code d'invitation, membres et rôles |
| `lib/features/home` | Accueil et échéancier personnel |
| `lib/features/tontines` | Liste, création, détail, tours, paiements, tirage vérifiable avec tours attribués |
| `lib/features/cagnottes` | Cagnottes solidaires et à gagnants : compte à rebours, participations, tickets, gains, tirage vérifiable, remises |
| `lib/features/profile` | Profil, aide, guide, confidentialité, à propos |

Aucune donnée n'est inventée : tout ce qui concerne les tontines, les membres et les cotisations vient de l'API.

## Charte graphique

- **Couleurs** : vert feuille `#1E7A4C` (marque), or `#E0A526` (argent reçu), indigo `#2F3E8F` (tirage), rouge piment `#B83227` (retards), fond coton `#F3F6F1`.
- **Titres** : Young Serif, une seule graisse. La hiérarchie se fait par la taille.
- **Textes, boutons, montants et codes** : Atkinson Hyperlegible, regular et gras, choisie pour sa lisibilité (0 et O, 1 et I bien distincts).
- **Élément signature** : la bande tissée (`WovenBand`), une case par tour, inspirée des rayures du Faso Dan Fani.

Les polices sont **embarquées dans l'application** (`assets/google_fonts/`, 216 Ko au total) : elles s'affichent sans connexion dès le premier lancement. `google_fonts` les retrouve par leur nom de fichier et le téléchargement est désactivé dans `main.dart`. Pour ajouter une graisse, déposer le fichier au nom attendu (par exemple `AtkinsonHyperlegible-Italic.ttf`) dans ce dossier. Les licences SIL Open Font License sont incluses et visibles dans « À propos », « Licences des composants ».

Pour obtenir du gras, utiliser `AppType.sans(bold: true)` et non `copyWith(fontWeight: ...)`, qui produirait un gras artificiel.

## Tests

```bash
flutter analyze && flutter test
```

Les tests `draw_verifier_test.dart` et `cagnotte_test.dart` vérifient, sur des valeurs calculées par l'API en PHP, que le téléphone retrouve exactement le même ordre de passage, les mêmes gagnants et les mêmes gains que le serveur.
