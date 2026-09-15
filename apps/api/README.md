# API Tontine BF

API Laravel 12 du SaaS. Authentification par OTP SMS et jeton Sanctum, données cloisonnées par organisation.

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

En local, `LogOtpSender` écrit les codes OTP dans `storage/logs/laravel.log`. En production, l'application refuse de démarrer l'envoi tant qu'aucun fournisseur SMS n'est branché.

## Règles clés

- **Identité** : numéro de téléphone burkinabè normalisé en `+226XXXXXXXX`, vérifié par un code à 6 chiffres (10 minutes, 5 essais, 3 demandes par numéro sur 10 minutes).
- **Cloisonnement** : toutes les routes métier sont sous `/orgs/{organization}`, protégées par le middleware `org.member` et par `scopeBindings()`. Une ressource d'une autre organisation répond 404, une organisation dont on n'est pas membre répond 403.
- **Rôles** : `owner` et `admin` gèrent, `tresorier` enregistre les paiements et voit toutes les tontines, `membre` ne voit que ses tontines. Le numéro des autres membres est masqué pour un simple membre.
- **Montants** : entiers en francs CFA.
- **Cotisations** : le trésorier enregistre, le membre confirme. Une cotisation confirmée ne peut plus être modifiée.
- **Tirage vérifiable** (type `tirage_ordre`) : l'empreinte `sha256` de la graine est publiée d'abord, la graine n'est révélée qu'après la date annoncée, et l'ordre se recalcule sans l'application. Le responsable peut attribuer des tours (`designations`) : ils sont publiés avec l'empreinte et visibles de tous.
- **Cagnottes** : durée `flash_24h`, `hebdo_7j`, `mensuelle_30j` ou `personnalisee` ; une cagnotte ouverte dont `ends_at` est passé est vue comme clôturée. Mode `solidaire` : remise des fonds enregistrée par un responsable, confirmée par le bénéficiaire membre. Mode `gagnants` : un ticket par tranche de `ticket_price`, gains répartis selon `prize_split` après `fee_percent`, rangs attribués modifiables tant qu'aucune participation n'existe, tirage vérifiable après clôture, remise de chaque gain confirmée par le gagnant.
- **Paiements PayDunya** : le membre paie lui-même sa cotisation ou sa participation sur la page PayDunya. Le statut est toujours relu auprès de l'API PayDunya (notification signée ou retour dans l'application), puis appliqué une seule fois : la cotisation ou la participation est alors enregistrée et confirmée. Un montant différent du montant attendu n'est jamais appliqué. Les remises de gains et de fonds peuvent partir par PayDunya (`method: paydunya`, `withdraw_mode`, `phone`) si `PAYDUNYA_PAYOUTS_ENABLED=true` : il n'existe pas de sandbox pour ces envois.
- **Erreurs** : validation en 422 avec `errors`, règle métier en 422 avec `message`, droits en 403.

## Endpoints `/api/v1`

| Méthode | Chemin | Accès |
|---|---|---|
| POST | `auth/otp/request` | public |
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
| PUT | `.../cagnottes/{cagnotte}/designations` | owner, admin, avant toute participation |
| POST | `.../cagnottes/{cagnotte}/draw` et `.../draw/reveal` | owner/admin après clôture, puis membre après `reveal_after` |
| POST | `.../cagnottes/{cagnotte}/winners/{winner}/payout` et `.../confirm` | owner/admin, puis le gagnant |
| POST | `.../cycles/{cycle}/contributions/{contribution}/pay` | le membre concerné, renvoie `checkout_url` |
| POST | `orgs/{org}/cagnottes/{cagnotte}/pay {"amount"}` | membre, renvoie `checkout_url` |
| GET | `orgs/{org}/payments/{payment}` | le payeur, trésorier ou responsables (relit le statut chez PayDunya) |
| POST | `payments/paydunya/ipn`, `payouts/paydunya/callback` | PayDunya uniquement (signature SHA-512 de la clé principale) |

## Parcours type

1. `POST auth/otp/request {"phone": "70 12 34 56"}` puis `POST auth/otp/verify {"phone": "70123456", "code": "123456"}`.
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
