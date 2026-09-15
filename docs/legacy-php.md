# Analyse de l'ancien backend PHP

Source : archive `api.zip` fournie le 15/09/2026 (9 fichiers, versions de septembre à novembre 2025). L'archive n'est pas versionnée dans ce dépôt car elle contient les identifiants de la base de données.

Conclusion : **aucune donnée ni aucun code à migrer**. Il n'y a pas d'utilisateurs réels et le backend n'était que partiellement fonctionnel. La nouvelle API repart de zéro dans `apps/api`.

## Fichiers

| Fichier | Accès BD | Authentification | État |
|---|---|---|---|
| `auth_api.php` | mysqli, identifiants en clair | aucune | Fonctionnel : `register`, `login`, `get_user_info`, plus une action orpheline `create_cycle` |
| `tontine_api.php` | mysqli, identifiants en clair | aucune | `create_tontine`, `join_tontine`, `search_users` fonctionnels. `get_system_tontines`, `get_participants`, `generate_invitation`, `get_user_tontines` sont **vides** (commentaires « Ton code ») |
| `dashboard_api.php` | mysqli, identifiants en clair | aucune | Fonctionnel |
| `wallet_api.php` | mysqli | aucune | **Plante** : utilise les constantes `DB_SERVER`... sans les définir |
| `cagnotte_api.php` | PDO via `../config/database.php` (absent de l'archive) | `AuthMiddleware` | Attend des requêtes GET et un en-tête `Authorization` que l'app n'envoie jamais : répond 401 |
| `groupe_api.php` | idem | idem | idem, et les noms d'actions diffèrent de ceux de l'app (`get_groupes_user` contre `get_groupes_utilisateur`) |
| `notification_api.php` | idem | idem | Notifications calculées à la volée, « marquer comme lu » simulé |
| `tirage_api.php` | idem | idem | Tirage avec gagnants imposés par l'admin (voir plus bas) |
| `middlewares/AuthMiddleware.php` | PDO | | Un jeton numérique est accepté comme **identifiant utilisateur** : envoyer `Authorization: 5` suffit pour être l'utilisateur 5 |

## Schéma MySQL reconstitué

Aucun fichier SQL n'était fourni. Tables déduites des requêtes :

- `users` (id, full_name, phone_number unique, email, password bcrypt, is_verified)
- `user_sessions` (token, user_id, expires_at)
- `wallets` (id, user_id, balance), `transactions` (wallet_id, type, amount, description, status, reference, created_at)
- `tontines` (creator_id, nom, type, montant_cotisation, frequence, duree, max_participants, objectif, code_invitation, status)
- `tontine_participants` (tontine_id, user_id, is_creator)
- `cycles` (creator_id, name, amount_per_member, frequency, start_date, status)
- `cagnottes`, `participations_cagnotte` (montant, tickets), `gagnants_cagnotte` (rang, gain, mode_selection, message_victoire)
- `tirage_config` (cagnotte_id, rang, user_id, raison)
- `groupes_cagnotte`, `messages_groupe`

## Points de sécurité relevés

1. **Identifiants MySQL en clair** dans 3 fichiers déployés sur un serveur web. Action : changer le mot de passe de la base dans hPanel Hostinger, puis supprimer les scripts de `poupecosmetic.com/api/` puisqu'ils ne servent à aucun utilisateur.
2. **Tirage truqué** : `executerTirage()` lit `tirage_config`. Pour chaque rang configuré, le gagnant est l'utilisateur choisi par l'admin, sans tirage. Le gain est ensuite crédité sur son portefeuille. Seuls les rangs non configurés sont tirés au hasard. Ce mécanisme n'est pas repris.
3. **Aucune autorisation réelle** : `user_id` pris dans le corps de la requête (scripts mysqli) ou jeton égal à l'identifiant (scripts PDO).
4. **Messages d'erreur SQL** renvoyés au client, `display_errors` activé, CORS ouvert à tous.
5. **Montants en flottants** et répartition des gains arrondie à 2 décimales en francs CFA.

## Correspondance avec la nouvelle API

| Ancien | Nouveau (`/api/v1`) |
|---|---|
| `register`, `login` avec mot de passe | `POST auth/otp/request`, `POST auth/otp/verify` (jeton Sanctum) |
| `get_user_info` | `GET me` |
| `create_tontine` | `POST orgs/{org}/tontines` |
| `join_tontine` (code) | `POST invitations/{code}/accept` |
| `search_users` (annuaire ouvert) | supprimé, remplacé par les invitations |
| `get_dashboard_stats` | à venir |
| `wallet_api.php` | supprimé (pas de détention de fonds) |
| `cagnotte_api.php`, `tirage_api.php` | supprimés. Remplacés par le tirage vérifiable des tontines `tirage_ordre` |
| `groupe_api.php`, `notification_api.php` | reportés (phase 3) |
