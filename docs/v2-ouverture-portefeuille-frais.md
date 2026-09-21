# Chantier v2 : ouverture au public, portefeuille et frais de service

Cahier des charges à valider avant développement. Il reprend les idées du porteur du projet, les pousse jusqu'aux détails d'implémentation, et signale les points qui engagent juridiquement.

**Statut : proposition. Rien n'est développé tant que la section 9 n'est pas tranchée.**

---

## 0. En bref

| Sujet | Aujourd'hui | Après le chantier v2 |
|---|---|---|
| Adhésion | code d'invitation à saisir | lien partageable, QR, demande d'adhésion avec approbation |
| Organisation | privée, obligatoire | publique ou privée ; libre ou sur approbation ; facultative |
| Tontine | toujours liée à une organisation | privée (organisation) ou publique (ouverte aux demandes) |
| Cagnotte à gagnants | visible des membres de l'organisation | publique, visible de tous |
| Argent | chaque paiement passe par PayDunya, rien n'est conservé | portefeuille avec solde, dépôt et retrait |
| Revenus | aucun | frais de service sur chaque opération, commission sur les cagnottes |

Trois décisions structurantes sont demandées en section 9 : le montage du portefeuille (4.1), le niveau des frais (5.2) et l'ouverture ou non des tontines publiques à des inconnus (7.3).

---

## 1. Visibilité et adhésion

### 1.1 Principes

Trois objets deviennent partageables et visibles au-delà du cercle actuel : l'organisation, la tontine et la cagnotte. Chacun porte deux réglages indépendants.

| Réglage | Valeurs | Effet |
|---|---|---|
| `visibility` | `private`, `unlisted`, `public` | qui peut **voir** la fiche |
| `join_policy` | `closed`, `request`, `open` | qui peut **rejoindre**, et comment |

- `private` : visible uniquement des membres. C'est le comportement actuel, et il reste le défaut pour tout ce qui existe déjà.
- `unlisted` : invisible dans la recherche, mais accessible à qui possède le lien. C'est le mode naturel du partage WhatsApp.
- `public` : apparaît dans l'annuaire et la recherche.
- `closed` : on n'entre que par invitation nominative.
- `request` : n'importe qui peut demander, un responsable approuve ou refuse.
- `open` : l'adhésion est immédiate, sans approbation.

Cette séparation évite le piège du réglage unique : une tontine peut être `public` en visibilité et `request` en adhésion, ce qui est exactement le fonctionnement demandé.

### 1.2 Organisation

- Une organisation peut être publique ou privée, en accès libre ou sur approbation, comme un groupe WhatsApp.
- Une personne peut appartenir à plusieurs organisations, et l'application garde le sélecteur d'organisation existant.
- **Personne n'est obligé d'appartenir à une organisation.** L'application crée pour chaque compte un espace personnel implicite, qui porte ses tontines publiques, ses participations aux cagnottes et son portefeuille. Techniquement, c'est une organisation de type `personal` créée à la première connexion, jamais listée dans l'annuaire, dont le membre est seul propriétaire. Cela évite de dupliquer toute la logique de cloisonnement déjà testée.
- Un compte peut donc utiliser l'application sans jamais rejoindre un groupe : il voit l'annuaire public, rejoint des tontines publiques, garde son portefeuille.

### 1.3 Tontine

- **Privée** : rattachée à une organisation, visible de ses membres selon les règles actuelles (un membre ne voit que les tontines où il participe, le trésorier et les responsables voient tout).
- **Publique** : visible de tous, y compris des comptes qui n'appartiennent à aucune organisation. Le créateur reçoit les demandes d'adhésion, approuve ou refuse, et gère ensuite ses membres.
- Une tontine publique reste rattachée à l'espace personnel ou à l'organisation de son créateur. Les rôles existants (`owner`, `admin`, `tresorier`, `membre`) s'appliquent sans changement.
- Le créateur d'une tontine publique obtient les pouvoirs de gestion sur **cette tontine seulement** : accepter, refuser, exclure un membre, fixer les parts, démarrer, et désigner un trésorier.
- Ce qu'un non-membre voit d'une tontine publique : le nom, le type, le montant par tour, la fréquence, le nombre de places restantes, la date de démarrage prévue, le nom public du créateur et son ancienneté. Jamais les numéros de téléphone, jamais la liste nominative des membres, jamais les cotisations individuelles.

### 1.4 Cagnotte

- **Cagnotte à gagnants : publique par défaut**, visible de tous. C'est la demande, et c'est cohérent avec la promesse de tirage vérifiable : plus il y a de témoins, plus la preuve vaut.
- **Cagnotte solidaire : privée par défaut**, avec possibilité de la rendre publique ou accessible par lien. Une collecte pour un décès ou une maladie ne se publie pas sans accord, et le bénéficiaire doit pouvoir refuser la publicité. Prévoir une case explicite « Rendre cette cagnotte visible de tous », décochée au départ, et un avertissement quand le bénéficiaire est une personne nommée.
- Participer à une cagnotte publique ne demande aucune approbation : c'est un paiement, pas une adhésion.

### 1.5 Matrice de référence

| Objet | Visibilité par défaut | Adhésion par défaut | Qui approuve |
|---|---|---|---|
| Organisation | `private` | `closed` | propriétaire, admin |
| Organisation publique | `public` | `request` ou `open` | propriétaire, admin |
| Tontine d'organisation | héritée de l'organisation | `closed` | responsables |
| Tontine publique | `public` | `request` | créateur de la tontine |
| Cagnotte solidaire | `private` | sans objet | sans objet |
| Cagnotte à gagnants | `public` | sans objet | sans objet |

### 1.6 Demandes d'adhésion

Nouvelle table `join_requests` : objet visé (organisation ou tontine), demandeur, message facultatif, statut (`pending`, `approved`, `rejected`, `withdrawn`), qui a tranché et quand.

Règles :
- une seule demande active par personne et par objet ;
- un refus peut être accompagné d'un motif, envoyé au demandeur ;
- trois refus successifs par le même demandeur sur le même objet bloquent les nouvelles demandes pendant 30 jours ;
- une demande sur une tontine déjà démarrée est refusée automatiquement, avec le motif « les inscriptions sont fermées depuis le démarrage » ;
- l'approbation d'une demande sur une tontine publique fait aussi entrer le demandeur dans l'organisation porteuse, avec le rôle `membre`, sauf si cette organisation est `private` et `closed`, auquel cas l'adhésion reste limitée à la tontine.

---

## 2. Partage par lien

### 2.1 Forme des liens

```
https://<domaine>/t/<code>     tontine
https://<domaine>/c/<code>     cagnotte
https://<domaine>/o/<code>     organisation
```

- `code` : 10 caractères tirés d'un alphabet sans ambiguïté (pas de 0/O ni 1/l), stocké haché comme les codes d'invitation actuels.
- Trois familles de liens, toutes dans la même table `share_links` :

| Type | Usage | Expiration | Cas d'usage |
|---|---|---|---|
| `permanent` | illimité | aucune | page publique d'une cagnotte |
| `invite` | illimité ou limité à N usages | 30 jours par défaut | lien WhatsApp d'une tontine |
| `nominative` | un seul usage, lié à un numéro | 7 jours | invitation d'un membre précis |

- Un responsable peut révoquer un lien, ce qui n'affecte pas les membres déjà entrés.
- Chaque ouverture est comptée (`hits`) pour que le créateur voie si son lien circule.

### 2.2 Comportement à l'ouverture

L'adresse ouvre d'abord une **page web légère servie par l'API**, qui affiche la fiche publique et adapte la suite :

1. application installée : l'Android App Link ouvre directement l'écran concerné ;
2. application absente : la page propose le téléchargement de l'APK, puis rouvre le lien après installation (le code est conservé dans le presse-papier et relu au premier lancement) ;
3. visiteur non connecté : la page montre la fiche, la connexion se fait dans l'application ;
4. membre déjà inscrit : ouverture directe de la fiche, sans nouvelle demande ;
5. lien expiré ou révoqué : message clair, avec le nom du créateur à contacter.

Le partage propose en plus un **QR code** (utile en réunion) et un texte prêt à envoyer sur WhatsApp, du type : « Rejoins notre tontine "Marché de Gounghin" sur Tontine BF : 5 000 FCFA par semaine, 12 membres. <lien> ».

### 2.3 Travaux techniques

- `assetlinks.json` servi à la racine du domaine, empreinte SHA-256 de la clé de signature de l'APK (aujourd'hui la clé de débogage, donc **il faut d'abord créer une clé de signature de release**, à conserver hors dépôt).
- `intent-filter` App Links dans le manifeste Android, avec `autoVerify`.
- Page web de repli en Blade, sobre, sans dépendance externe, qui réutilise les couleurs de l'application.
- Suivi minimal : nombre d'ouvertures, nombre d'installations attribuées, nombre d'adhésions issues du lien.

---

## 3. Découverte publique

- **Annuaire** : liste des tontines et cagnottes publiques, triée par pertinence (proximité de la date de démarrage, places restantes, ancienneté du créateur, activité récente).
- **Filtres** : type de tontine, montant par tour, fréquence, places restantes, ville ou région déclarée par le créateur.
- **Recherche plein texte** sur le nom et la description, avec `LIKE` en SQLite au lancement, à remplacer par un index dédié si le volume l'exige.
- **Signalement** : bouton « Signaler » sur chaque fiche publique, motifs prédéfinis (arnaque, contenu trompeur, montants irréalistes, usurpation). Trois signalements distincts masquent automatiquement la fiche de l'annuaire en attendant examen, sans supprimer la tontine ni bloquer ses membres actuels.
- **Back-office de modération** : file des signalements, fiche du créateur, historique de ses objets, action de masquage ou de blocage.

Sans cette modération, l'annuaire public devient rapidement un support d'escroquerie. Ce point n'est pas optionnel, il fait partie du lot d'ouverture.

---

## 4. Portefeuille

### 4.1 Deux montages possibles, et le risque réglementaire

Conserver le solde d'un utilisateur, c'est encaisser des fonds remboursables du public. Dans l'UEMOA, cette activité relève de la BCEAO et demande un agrément d'établissement de monnaie électronique, ou un partenariat avec un établissement déjà agréé. Ce n'est pas une formalité, et l'exercer sans agrément expose à la fermeture des comptes de collecte par l'agrégateur lui-même.

Deux montages, à trancher :

**Montage A, « solde de transit » (recommandé pour démarrer).** Le solde n'existe que pour de l'argent déjà entré dans le système au titre d'une opération : gain d'une cagnotte à recevoir, remboursement d'une participation annulée, trop-perçu. L'utilisateur peut le retirer ou l'utiliser pour payer une cotisation, mais **il ne peut pas déposer librement**. L'argent ne stationne que le temps de la remise. Le risque réglementaire reste faible, le développement est le même que pour le montage B à l'exception de l'écran de dépôt.

**Montage B, « portefeuille complet ».** Dépôt libre, solde conservé, retrait à la demande. C'est ce qui est souhaité à terme, et c'est ce qui demande le cadrage juridique. À n'ouvrir qu'après avoir écrit noir sur blanc : qui détient les fonds, sur quel compte, sous quel statut, et ce qui se passe si l'application s'arrête.

**Proposition : construire l'infrastructure complète (comptes, écritures, plafonds, retraits) et n'activer le dépôt libre que par un réglage, `WALLET_DEPOSITS_ENABLED`, laissé à `false` jusqu'au feu vert juridique.** Le même code sert les deux montages, la bascule est une ligne de configuration.

### 4.2 Modèle de données, en comptabilité à double entrée

Chaque mouvement d'argent écrit deux lignes égales et opposées. C'est la seule façon de prouver plus tard où est passé chaque franc.

| Table | Contenu |
|---|---|
| `accounts` | un compte par utilisateur (`user:<id>`), par organisation (`org:<id>`), plus les comptes système : `platform:revenue`, `platform:fees_paydunya`, `settlement:paydunya`, `suspense` |
| `ledger_entries` | `transaction_id`, `account_id`, `direction` (débit/crédit), `amount` (entier FCFA), `currency`, `created_at`, référence de l'objet métier |
| `wallet_transactions` | vue métier lisible : type (`deposit`, `withdrawal`, `contribution`, `prize`, `fee`, `refund`, `transfer`), statut, montant, frais, solde après opération |

Règles non négociables :
- montants entiers en francs CFA, jamais de flottant ;
- somme des écritures d'une transaction toujours nulle ;
- solde d'un compte = somme de ses écritures, jamais une colonne modifiable à la main ;
- toute écriture est immuable ; une erreur se corrige par une écriture inverse, pas par une suppression ;
- réconciliation quotidienne avec les relevés PayDunya, écart consigné dans `suspense` et remonté au back-office.

### 4.3 Opérations

| Opération | Flux d'argent | Frais supportés par |
|---|---|---|
| Dépôt | PayDunya PayIn vers le compte de collecte, crédit du compte utilisateur | l'utilisateur |
| Retrait | débit du compte utilisateur, PayDunya PayOut vers son mobile money | l'utilisateur |
| Cotisation payée depuis le solde | débit utilisateur, crédit organisation ou bénéficiaire | l'organisation ou le membre, selon le réglage de la tontine |
| Participation à une cagnotte | débit utilisateur, crédit cagnotte | le participant |
| Versement d'un gain ou d'un tour | débit cagnotte ou tontine, crédit bénéficiaire | le bénéficiaire |
| Transfert entre membres | débit, crédit, sans passage par PayDunya | gratuit au lancement |

Le transfert interne ne coûte rien à la plateforme : c'est un simple jeu d'écritures. Le laisser gratuit est un argument d'adoption fort, et il ramène de l'argent dans le système au lieu de le faire sortir.

### 4.4 Plafonds et vérification progressive

| Niveau | Conditions | Plafonds |
|---|---|---|
| 0, nouveau compte | numéro vérifié | solde 100 000 FCFA, retrait 50 000 FCFA par jour |
| 1, confirmé | 30 jours d'ancienneté, 3 opérations réussies | solde 500 000 FCFA, retrait 200 000 FCFA par jour |
| 2, vérifié | pièce d'identité contrôlée | à définir avec le partenaire financier |

- Retrait uniquement vers un numéro mobile money appartenant au titulaire, vérifié une première fois par un code.
- Délai de sécurité de 24 heures sur le premier retrait après un changement de numéro.
- Blocage automatique et revue manuelle au-delà d'un seuil de vélocité (par exemple 10 opérations en 10 minutes).

### 4.5 Échecs et litiges

- Un dépôt dont la notification n'arrive jamais reste en attente et se résout par la relecture du statut chez PayDunya, comme les paiements actuels.
- Un retrait refusé par l'opérateur recrédite le compte et consigne le motif.
- Un litige déclaré par un membre gèle la somme concernée dans `suspense` jusqu'à décision, sans bloquer le reste du solde.
- Toute opération montre un reçu avec le détail des frais et une référence unique, exportable en PDF.

---

## 5. Moteur de frais

### 5.1 Ce que coûte réellement chaque mouvement

Source : [grille tarifaire officielle PayDunya, septembre 2026](https://paydunya.com/service-fees).

| Opération | Burkina Faso | Observation |
|---|---|---|
| Encaissement mobile money (PayIn) | **2,25 %** | 2,20 % au-delà de 100 M FCFA de flux mensuel, 2,15 % au-delà de 500 M |
| Encaissement carte bancaire | **3,50 %** | marginal ici |
| Reversement mobile money (PayOut) | **2,00 %** | 1,80 % puis 1,50 % selon le flux mensuel |

Aller-retour complet : **4,25 % du montant**. C'est le plancher absolu. Toute grille de frais qui descend en dessous fait perdre de l'argent à chaque opération.

Vocabulaire proposé : parler de **frais de service**, jamais de « taxe ». Une taxe désigne un prélèvement de l'État, et l'amalgame détruirait la confiance le jour où un membre poserait la question.

### 5.2 Grille proposée

| Opération | Frais proposés | Ce qui reste à la plateforme | Payé par |
|---|---|---|---|
| Dépôt sur le portefeuille | 3,00 %, minimum 100 FCFA | 0,75 % | déposant |
| Retrait vers mobile money | 2,50 %, minimum 100 FCFA | 0,50 % | retirant |
| Transfert entre membres | 0 | 0 | sans objet |
| Cotisation payée depuis le solde | 1,00 %, plafond 500 FCFA | 1,00 % | membre ou organisation, au choix du créateur |
| Cotisation payée en ligne sans solde | 3,25 % | 1,00 % | membre |
| Cotisation en espèces enregistrée par le trésorier | 0 | 0 | sans objet |
| Versement d'un tour au bénéficiaire | 1,00 % du pot, plafond 2 000 FCFA | variable | bénéficiaire du tour |
| Cagnotte à gagnants | **5 % du pot**, en plus de la commission de l'organisation | 5 % | prélevé sur le pot avant partage |
| Cagnotte solidaire | 2 % du montant remis, plafond 5 000 FCFA | 2 % | prélevé à la remise |
| Remise par PayDunya vers un mobile money | 2,50 % | 0,50 % | bénéficiaire |

Exemples chiffrés, à afficher tels quels dans l'application :

- **Cotisation de 5 000 FCFA payée en ligne** : 3,25 % de frais, arrondis à 165 FCFA. Le membre paie 5 165 FCFA, dont environ 113 FCFA pour PayDunya et 52 FCFA pour la plateforme.
- **Tour de 60 000 FCFA versé au bénéficiaire** : 600 FCFA de frais de service, le bénéficiaire reçoit 59 400 FCFA, moins 1 485 FCFA de frais de remise si le versement part en mobile money au lieu d'aller sur son solde.
- **Cagnotte à gagnants, 100 000 FCFA collectés, commission d'organisation 10 %** : 5 000 FCFA pour la plateforme, 10 000 FCFA pour l'organisation, 85 000 FCFA partagés entre les gagnants.
- **Dépôt de 10 000 FCFA puis retrait immédiat** : 300 + 250 = 550 FCFA, soit 5,5 %. C'est volontairement dissuasif : le portefeuille sert à faire circuler l'argent dans l'application, pas à servir de guichet.

Le point d'attention : cumulés, ces frais peuvent atteindre 8 à 10 % sur un parcours complet. Dans une tontine traditionnelle, le service est gratuit. L'application doit donc justifier ces frais par la preuve, la traçabilité et le tirage vérifiable, et **les afficher avant chaque confirmation**, sans exception.

### 5.3 Paramétrage

Table `fee_rules` : type d'opération, portée (globale, par organisation, par plan d'abonnement), pourcentage, montant fixe, minimum, plafond, date de début, date de fin, actif.

- Aucun pourcentage en dur dans le code.
- Une règle n'est jamais modifiée : on la clôt et on en crée une nouvelle, pour que l'historique reste explicable.
- Chaque prélèvement écrit une ligne `fee_charges` qui garde la règle appliquée, le montant, et l'opération concernée.
- Arrondi au multiple de 5 FCFA supérieur, la pièce la plus petite en circulation.
- Les organisations d'un plan payant peuvent obtenir des frais réduits : c'est le levier commercial de l'abonnement décrit dans le guide SaaS.

### 5.4 Transparence

- Écran de confirmation systématique : « Vous payez 5 163 FCFA. Cotisation 5 000, frais 163. »
- Reçu après chaque opération, avec la référence et le détail.
- Page « Frais » dans l'application, tenue à jour depuis l'API, consultable sans être connecté.
- Simulateur à la création d'une tontine ou d'une cagnotte : le créateur voit ce que recevra le bénéficiaire avant de publier.

### 5.5 Fiscalité et facturation

À cadrer avec un comptable burkinabè avant l'ouverture : TVA applicable aux commissions, obligation de facture, déclaration des revenus de la plateforme, et traitement des cagnottes à gagnants qui peuvent relever d'une fiscalité propre aux jeux.

---

## 5 bis. Notifications et relances

Une tontine se tient par les rappels. Aujourd'hui l'application ne prévient personne : tout repose sur le trésorier
qui relance de vive voix. C'est le premier manque signalé à l'usage.

### Ce qui déclenche une notification

| Moment | Qui reçoit | Message |
|---|---|---|
| 3 jours avant l'échéance d'un tour | chaque membre qui doit cotiser | « Votre cotisation de 5 000 FCFA est attendue vendredi. » |
| Le jour de l'échéance | les membres non encore enregistrés | « C'est aujourd'hui : 5 000 FCFA pour le tour 4. » |
| 2 jours après, puis tous les 3 jours | les retardataires, et un récapitulatif au trésorier | « Vous avez 2 jours de retard. » |
| Paiement enregistré par le trésorier | le membre concerné | « Le trésorier a enregistré 5 000 FCFA. Confirmez si c'est exact. » |
| Paiement confirmé | le trésorier | « Awa a confirmé sa cotisation. » |
| Tour réglé | le bénéficiaire du tour | « Votre tour est complet : 60 000 FCFA à recevoir. » |
| Cagnotte : 24 h avant la clôture | les membres qui n'ont pas participé | « Il reste un jour pour participer. » |
| Cagnotte : tirage révélé | tous les participants | « Les gagnants sont connus. » |
| Gain ou fonds remis | le bénéficiaire | « Confirmez la réception de 59 400 FCFA. » |
| Demande d'adhésion (L2) | les responsables | « Binta demande à rejoindre votre tontine. » |
| Paiement en ligne validé | le payeur | « Paiement de 5 165 FCFA validé. » |

### Ce qui les rend intelligentes

- **Regroupement** : un membre de trois tontines reçoit un seul message le matin, pas trois. Une file quotidienne
  regroupe par personne avant l'envoi.
- **Silence utile** : rien n'est envoyé à qui a déjà payé, rien n'est renvoyé si le membre a ouvert l'application
  depuis le dernier rappel, et jamais deux fois le même message dans la journée.
- **Heures décentes** : envoi entre 7 h et 20 h heure de Ouagadougou. Ce qui tombe en dehors attend le matin.
- **Montant juste** : le message porte le reste à payer, pas le montant du tour, quand une partie a déjà été versée.
- **Ton adapté au retard** : rappel neutre avant l'échéance, ferme après, et jamais de message culpabilisant qui
  circulerait en capture d'écran dans le groupe WhatsApp.
- **Réglages par membre** : chacun choisit ce qu'il reçoit et par quel canal, avec un interrupteur « ne plus me
  relancer pour cette tontine ». Un rappel qu'on ne peut pas couper devient un spam.
- **Trace** : chaque envoi est enregistré (quoi, à qui, quand, par quel canal, résultat), pour prouver qu'un membre
  a bien été prévenu avant une exclusion.

### Canaux, par ordre de coût

| Canal | Coût | Remarque |
|---|---|---|
| Notification dans l'application | gratuit | visible seulement à l'ouverture, insuffisante seule |
| Push Android (Firebase) | gratuit | demande le service Firebase et une clé ; le plus rentable |
| WhatsApp | payé par message | idéal pour les relances de paiement, modèle à faire approuver |
| SMS | le plus cher | à réserver aux retards importants et aux membres sans smartphone |
| E-mail | gratuit avec la boîte LWS | utile pour les récapitulatifs du trésorier |

Proposition : push Firebase pour tout le monde, WhatsApp pour les relances de paiement et les remises, e-mail pour
les récapitulatifs hebdomadaires du trésorier, SMS gardé en secours et facturé au plan payant.

### Travaux

Table `notifications` (destinataire, type, objet, canal, état, dates), table `notification_settings` par membre,
file d'attente traitée par le cron existant, planificateur pour les échéances, et un écran « Notifications » dans
l'application avec l'historique et les réglages.

## 6. Impacts sur l'existant

### API

| Élément | Travail |
|---|---|
| `organizations` | colonnes `visibility`, `join_policy`, `kind` (`standard`, `personal`), `city` |
| `tontines`, `cagnottes` | mêmes colonnes de visibilité, plus `created_by` déjà présent |
| Nouvelles tables | `join_requests`, `share_links`, `accounts`, `ledger_entries`, `wallet_transactions`, `fee_rules`, `fee_charges`, `reports` |
| Portées d'accès | le middleware `org.member` ne suffit plus : ajouter une politique `can_view` par objet, qui accepte le membre, le porteur d'un lien valide, ou tout le monde si l'objet est public |
| Endpoints | annuaire, recherche, demandes d'adhésion, gestion des membres d'une tontine, liens de partage, portefeuille (solde, dépôt, retrait, transferts, historique), frais (grille, simulation) |
| Paiements | brancher le moteur de frais sur les paiements PayDunya existants, sans toucher à la relecture de statut qui fonctionne |

### Application

Nouveaux écrans : annuaire et recherche, fiche publique, demande d'adhésion, file des demandes pour le créateur, gestion des membres d'une tontine, portefeuille (solde, historique, dépôt, retrait, transfert), reçus, page des frais, partage avec QR.

Écrans modifiés : création de tontine et de cagnotte (visibilité, adhésion, qui paie les frais), paiement (affichage des frais, choix solde ou mobile money), profil (niveau de vérification, numéro de retrait).

### Documentation

`README` de l'API, guide SaaS (modèle économique et schéma de données), documentation de déploiement (nouvelles variables d'environnement), et une note publique sur les frais.

---

## 7. Risques et garde-fous

### 7.1 Détention de fonds

Traité en 4.1. Décision à prendre avant toute ligne de code sur le dépôt libre.

### 7.2 Cagnottes à gagnants publiques

Ouvrir au public une cagnotte où l'on paie un ticket pour gagner une part du pot rapproche l'activité d'une loterie, régulée au Burkina Faso comme ailleurs. Tant que la cagnotte reste dans un cercle privé, l'argument du jeu entre membres tient. Publique, il ne tient plus. À vérifier auprès d'un juriste avant d'activer la visibilité publique de ce mode précis, et prévoir dès maintenant un interrupteur `PUBLIC_PRIZE_POOLS_ENABLED` pour pouvoir le refermer sans redéployer.

### 7.3 Tontines publiques entre inconnus

Une tontine repose sur la confiance : le bénéficiaire du premier tour peut disparaître après avoir encaissé. Entre membres d'un même groupement, la pression sociale suffit. Entre inconnus, non.

Garde-fous proposés :
- afficher l'ancienneté du créateur et son nombre de tontines menées à terme ;
- limiter le montant par tour des tontines publiques d'un créateur qui n'a pas encore d'historique (proposition : 10 000 FCFA maximum) ;
- ordre de passage tiré au sort obligatoire pour les tontines publiques, sans tour attribué ;
- afficher un avertissement explicite avant de rejoindre : « Vous vous engagez à cotiser jusqu'à la fin. L'application enregistre et prouve, elle ne garantit pas les paiements. » ;
- à terme, séquestre des cotisations dans le portefeuille jusqu'au versement du tour, ce qui n'a de sens qu'avec le montage B validé.

### 7.4 Sécurité et abus

Limitation de débit sur les demandes d'adhésion et les créations d'objets publics, blocage d'un compte signalé, journal des actions sensibles, et double confirmation pour tout retrait supérieur à un seuil.

### 7.5 Données personnelles

L'ouverture au public élargit ce qui est visible. Règle simple : aucun numéro de téléphone, aucune adresse e-mail, aucun montant individuel n'apparaît sur une fiche publique. Le nom affiché devient un pseudonyme modifiable, distinct du nom réel utilisé dans l'organisation.

---

## 8. Découpage proposé

| Lot | Contenu | Dépendances | Estimation |
|---|---|---|---|
| **L1. Visibilité et liens** ✅ livré | `visibility` et `join_policy`, codes de partage, fiche publique sans donnée personnelle, page web de repli, App Links, QR, partage WhatsApp, lien accepté à la place du code | aucune | fait |
| **L2. Adhésion** ✅ livré | `join_requests`, annuaire public avec recherche, demande d'adhésion et approbation, adhésion libre, signalement qui masque après trois alertes | L1 | fait |
| **L3. Moteur de frais** | `fee_rules`, `fee_charges`, calcul, affichage avant confirmation, reçus, page des frais | aucune | 1 semaine |
| **L4. Portefeuille, socle** | comptes, écritures, historique, paiement d'une cotisation depuis le solde, transferts internes | L3 | 1 à 2 semaines |
| **L5. Portefeuille, entrées et sorties** | dépôt (désactivable), retrait, plafonds, vérification du numéro, réconciliation | L4, décision 4.1 | 1 semaine |
| **L6. Modération et confiance** | back-office des signalements (la file existe déjà en base), historique du créateur, limites des tontines publiques | L2 | 1 semaine |
| **L7. Notifications et relances** | voir section 5 bis | L3 pour les montants, L2 pour les demandes | 1 à 2 semaines |

L1 à L3 peuvent être livrés sans trancher la question réglementaire. L4 et L5 attendent la décision.

---

## 9. À valider avant de commencer

1. **Portefeuille** : montage A (solde de transit, dépôt désactivé) pour démarrer, ou montage B (dépôt libre) tout de suite malgré le risque réglementaire ?
2. **Niveau des frais** : la grille du 5.2 est-elle acceptée telle quelle ? En particulier les 3 % sur le dépôt et les 5 % sur les cagnottes à gagnants.
3. **Qui paie les frais d'une cotisation** : le membre, ou l'organisation qui peut choisir de les absorber ?
4. **Tontines publiques** : ouvertes à tous dès le départ, ou réservées d'abord aux créateurs ayant déjà mené une tontine à terme ?
5. **Cagnotte à gagnants publique** : activée dès la v2, ou gardée privée le temps de la vérification juridique ?
6. **Cagnotte solidaire** : publique par défaut, ou privée par défaut comme je le propose ?
7. **Pseudonyme public** : obligatoire pour tout compte apparaissant sur une fiche publique, ou nom réel affiché ?
8. **Transfert entre membres** : gratuit comme proposé, ou facturé 0,5 % pour éviter l'usage de l'application comme service de transfert d'argent ?
9. **Plafonds** : les niveaux du 4.4 conviennent-ils pour le Burkina Faso ?
10. **Priorité de livraison** : l'ordre L1 à L7, ou le portefeuille d'abord parce qu'il porte le modèle économique ?
11. **Canaux de notification** : la répartition proposée en 5 bis convient-elle (push gratuit pour tous, WhatsApp pour les relances de paiement, e-mail pour le trésorier, SMS en secours) ? Le push demande d'ouvrir un compte Firebase.

Une fois ces dix points tranchés, ce document devient le cahier des charges des lots, et chaque lot est développé avec ses tests, comme le reste du projet.
