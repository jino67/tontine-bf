import '../features/tontines/models.dart';

/// Explication de chaque type de tontine, affichée dans le guide et à la création.
class TontineGuide {
  const TontineGuide({
    required this.type,
    required this.summary,
    required this.steps,
    required this.example,
    required this.suitedFor,
  });

  final TontineType type;
  final String summary;

  /// Étapes dans l'ordre où elles se déroulent.
  final List<String> steps;
  final String example;
  final String suitedFor;
}

const tontineGuides = [
  TontineGuide(
    type: TontineType.rotative,
    summary: 'Chaque membre reçoit la cagnotte à son tour, dans un ordre fixé à l’avance.',
    steps: [
      'Le responsable crée la tontine et fixe le montant et la fréquence.',
      'Les membres rejoignent avec le code d’invitation, puis l’ordre de passage est arrêté.',
      'À chaque tour, tout le monde cotise et un membre reçoit la totalité.',
      'La tontine s’arrête quand chaque part a reçu une fois.',
    ],
    example: '10 membres cotisent 5 000 FCFA chaque semaine. Chaque semaine, l’un d’eux reçoit 50 000 FCFA. '
        'Au bout de 10 semaines, tout le monde a reçu une fois.',
    suitedFor: 'Les groupes qui se connaissent bien et savent déjà qui a le plus besoin de passer en premier.',
  ),
  TontineGuide(
    type: TontineType.drawOrder,
    summary: 'Même fonctionnement que le tour de rôle, mais l’ordre de passage est tiré au sort.',
    steps: [
      'Le responsable démarre la tontine quand tous les membres ont rejoint.',
      'Il lance le tirage : une empreinte est publiée et une date de révélation est annoncée.',
      'Après cette date, n’importe quel membre révèle le tirage.',
      'Chaque téléphone vérifie que le résultat correspond à l’empreinte publiée.',
    ],
    example: 'Une coopérative de 12 productrices ne veut pas désigner qui passe en premier. '
        'Le tirage est lancé un vendredi et révélé le samedi à l’assemblée.',
    suitedFor: 'Les groupes où l’ordre de passage risque de créer des tensions.',
  ),
  TontineGuide(
    type: TontineType.groupSavings,
    summary: 'Le groupe épargne ensemble pendant une durée fixée, pour un objectif commun.',
    steps: [
      'Le responsable fixe le montant, la fréquence et le nombre de versements.',
      'Chaque membre cotise à chaque échéance.',
      'À la fin, la somme réunie sert l’objectif décidé ensemble.',
    ],
    example: '25 membres versent 2 000 FCFA par mois pendant 10 mois pour acheter des semences en gros avant l’hivernage.',
    suitedFor: 'Les achats groupés, les fêtes de fin d’année, les projets d’association.',
  ),
  TontineGuide(
    type: TontineType.solidarityPot,
    summary: 'Une collecte pour soutenir une personne ou un projet précis.',
    steps: [
      'Le responsable décrit l’objectif et le montant suggéré.',
      'Les membres cotisent pendant la durée prévue.',
      'Le trésorier suit ce qui a été réuni et le remet à qui de droit.',
    ],
    example: 'Une association de quartier réunit une participation mensuelle pour les frais de scolarité de deux orphelins.',
    suitedFor: 'Les coups durs, les événements familiaux, les actions de solidarité.',
  ),
  TontineGuide(
    type: TontineType.personalSavings,
    summary: 'Une épargne régulière pour vous seul, avec un rappel à chaque échéance.',
    steps: [
      'Vous fixez le montant, la fréquence et la durée.',
      'Le trésorier de votre organisation enregistre vos versements.',
      'Vous suivez votre progression jusqu’à l’objectif.',
    ],
    example: '1 000 FCFA par jour pendant 90 jours, soit 90 000 FCFA pour la rentrée scolaire.',
    suitedFor: 'Préparer une dépense importante sans toucher à l’argent du quotidien.',
  ),
];

TontineGuide guideFor(TontineType type) => tontineGuides.firstWhere((guide) => guide.type == type);

const sharesExplanation = 'Une part correspond à une cotisation par tour. Un membre qui prend deux parts '
    'cotise le double et reçoit la cagnotte deux fois.';
