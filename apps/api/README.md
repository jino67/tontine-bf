# API Tontine BF

API Laravel 12 du SaaS. Authentification par code à usage unique (par e-mail pendant les essais, puis WhatsApp ou SMS) et jeton Sanctum, données cloisonnées par organisation.

## Installation locale

```bash
composer install
```

```bash
cp .env.example .env && php artisan key:generate && php artisan migrate
```

```bash
php artisan test
```

Le canal des codes se choisit avec `OTP_CHANNEL`. `log`, par défaut, écrit les codes dans `storage/logs/laravel.log` et reste refusé en production. `mail` envoie le code à l'adresse e-mail liée au numéro ; à la première connexion, l'API répond 422 sur `email` et l'application demande l'adresse, liée au compte une fois le code vérifié. Les numéros listés dans `OTP_TEST_PHONES` se connectent avec `OTP_TEST_CODE` sans rien recevoir, sauf en production.

## Règles clés

- **Identité** : numéro de téléphone burkinabè normalisé en `+226XXXXXXXX`, vérifié par un code à 6 chiffres (10 minutes, 5 essais, 3 demandes par numéro sur 10 minutes).
- **Cloisonnement** : toutes les routes métier sont sous `/orgs/{organization}`, protégées par le middleware `org.member` et par `scopeBindings()`. Une ressource d'une autre organisation répond 404, une organisation dont on n'est pas membre répond 403.
- **Rôles** : `owner` et `admin` gèrent, `tresorier` enregistre les paiements et voit toutes les tontines, `membre` ne voit que ses tontines. Le numéro des autres membres est masqué pour un simple membre.
- **Montants** : entiers en francs CFA.
- **Cotisations** : le trésorier enregistre, le membre confirme. Une cotisation confirmée ne peut plus être modifiée.
- **Tirage vérifiable** (type `tirage_ordre`) : l'empreinte `sha256` de la graine est publiée d'abord, la graine n'est révélée qu'après la date annoncée, et l'ordre se recalcule sans l'application. Le responsable peut attribuer des tours (`designations`) : ils sont publiés avec l'empreinte et visibles de tous.
- **Cagnottes** : durée `flash_24h`, `hebdo_7j`, `mensuelle_30j` ou `personnalisee` ; une cagnotte ouverte dont `ends_at` est passé est vue comme clôturée. Mode `solidaire` : remise des fonds enregistrée par un responsable, confirmée par le bénéficiaire membre. Mode `gagnants` : un ticket par tranche de `ticket_price`, gains répartis selon `prize_split` après `fee_percent`, tous les gagnants tirés au sort de façon vérifiable après clôture (l'attribution d'un gain par le responsable est désactivée), remise de chaque gain confirmée par le gagnant.
- **Paiements PayDunya** : le membre paie lui-même sa cotisation ou sa participation sur la page PayDunya. Le statut est toujours relu auprès de l'API PayDunya (notification signée ou retour dans l'application), puis appliqué une seule fois : la cotisation ou la participation est alors enregistrée et confirmée. Un montant différent du montant attendu n'est jamais appliqué. Les remises de gains et de fonds peuvent partir par PayDunya (`method: paydunya`, `withdraw_mode`, `phone`) si `PAYDUNYA_PAYOUTS_ENABLED=true` : il n'existe pas de sandbox pour ces envois.
- **Partage** : chaque organisation, tontine et cagnotte porte `visibility` (`privee`, `lien`, `publique`) et, sauf les cagnottes, `join_policy` (`fermee`, `sur_demande`, `libre`). Le code de partage est créé au premier partage puis conservé, pour qu'un lien déjà envoyé continue de fonctionner. La fiche publique ne montre jamais de numéro, de liste de membres ni de montant individuel. Les pages `/t/<code>`, `/c/<code>`, `/o/<code>` et `/i/<code>` ouvrent l'application quand elle est installée (App Links, empreinte publiée dans `/.well-known/assetlinks.json`).
- **Erreurs** : validation en 422 avec `errors`, règle métier en 422 avec `message`, droits en 403.

## Endpoints `/api/v1`

| Méthode | Chemin | Accès |
|---|---|---|
| POST | `auth/otp/request {"phone", "email"}` | public, renvoie `channel` et `destination` masquée |
| POST | `auth/otp/verify` | public, renvoie `token` |
| POST | `auth/logout` | connecté |
| GET, PATCH | `me` | connecté |
| GET | `me/contributions?organization_id=` | connecté (ses propres cotisations, avec `is_late` et `is_beneficiary`) |
| GET, POST | `orgs` | connecté (le créateur devient `owner`) |
| POST | `invitations/{code}/accept` | connecté |
| GET | `orgs/{org}` | membre |
| GET | `orgs/{org}/members` | membre |
| PATCH | `orgs/{org}/members/{membership}` | owner |
| POST | `orgs/{org}/invitations` | owner, admin |
| GET | `orgs/{org}/tontines` | membre (filtré selon le rôle) |
| POST | `orgs/{org}/tontines` | owner, admin |
| GET | `orgs/{org}/tontines/{tontine}` | participant ou trésorier |
| POST | `orgs/{org}/tontines/{tontine}/members` | owner, admin |
| POST | `orgs/{org}/tontines/{tontine}/start` | owner, admin |
| GET | `orgs/{org}/tontines/{tontine}/cycles` | participant ou trésorier |
| GET | `orgs/{org}/tontines/{tontine}/cycles/{cycle}` | participant ou trésorier |
| PUT | `.../cycles/{cycle}/contributions/{contribution}` | trésorier, owner, admin |
| POST | `.../cycles/{cycle}/contributions/{contribution}/confirm` | le membre concerné |
| GET, POST | `orgs/{org}/tontines/{tontine}/draw` | lecture participant, création owner/admin |
| POST | `orgs/{org}/tontines/{tontine}/draw/reveal` | participant, après `reveal_after` |
| GET, POST | `orgs/{org}/cagnottes` | lecture membre, création owner/admin |
| GET | `orgs/{org}/cagnottes/{cagnotte}` | membre |
| POST | `orgs/{org}/cagnottes/{cagnotte}/close` | owner, admin |
| POST, PUT | `.../cagnottes/{cagnotte}/contributions[/{contribution}]` | trésorier, owner, admin |
| POST | `.../cagnottes/{cagnotte}/contributions/{contribution}/confirm` | la personne concernée |
| POST | `.../cagnottes/{cagnotte}/handover` et `.../handover/confirm` | owner/admin, puis le bénéficiaire |
| POST | `.../cagnottes/{cagnotte}/draw` et `.../draw/reveal` | owner/admin après clôture, puis membre après `reveal_after` |
| POST | `.../cagnottes/{cagnotte}/winners/{winner}/payout` et `.../confirm` | owner/admin, puis le gagnant |
| POST | `.../cycles/{cycle}/contributions/{contribution}/pay` | le membre concerné, renvoie `checkout_url` |
| POST | `orgs/{org}/cagnottes/{cagnotte}/pay {"amount"}` | membre, renvoie `checkout_url` |
| GET | `orgs/{org}/payments/{payment}` | le payeur, trésorier ou responsables (relit le statut chez PayDunya) |
| POST | `payments/paydunya/ipn`, `payouts/paydunya/callback` | PayDunya uniquement (signature SHA-512 de la clé principale) |
| GET | `links/{code}` | public : fiche d'un objet partagé ou d'une invitation |
| PUT | `orgs/{org}/sharing`, `.../tontines/{tontine}/sharing`, `.../cagnottes/{cagnotte}/sharing` | owner, admin |

## Parcours type

1. `POST auth/otp/request {"phone": "70 12 34 56"}` (avec `"email"` à la première connexion quand `OTP_CHANNEL=mail`) puis `POST auth/otp/verify {"phone": "70123456", "code": "123456"}`.
2. `POST orgs {"name": "Groupement Wend Panga"}`.
3. `POST orgs/1/tontines {"name": "Tontine du marché", "type": "rotative", "amount": 5000, "frequency": "hebdomadaire", "starts_on": "2026-10-05"}`.
4. `POST orgs/1/invitations {"tontine_id": 1}` puis partage du code. Chaque membre appelle `POST invitations/{code}/accept`.
5. `POST orgs/1/tontines/1/start` : cycles et cotisations générés.
6. Le trésorier enregistre `PUT .../contributions/{id} {"amount_paid": 5000, "method": "orange_money", "reference": "..."}`, le membre confirme.

## Valeurs des énumérations

- `type` : `rotative`, `tirage_ordre`, `epargne_groupe`, `epargne_perso`
- cagnotte `mode` : `solidaire`, `gagnants` ; `status` : `ouverte`, `cloturee`, `remise`, `tiree`, `annulee`
- `frequency` : `quotidien`, `hebdomadaire`, `mensuel`
- `method` : `especes`, `orange_money`, `moov_money`, `virement`, `autre`
- statut tontine : `brouillon`, `active`, `terminee`, `annulee`
- statut cycle : `a_venir`, `en_cours`, `regle`
- statut cotisation : `en_attente`, `enregistree`, `confirmee`
