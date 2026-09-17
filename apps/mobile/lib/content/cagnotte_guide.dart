import '../features/cagnottes/cagnotte.dart';

/// Explication des deux sortes de cagnottes, affichée à la création et dans la liste vide.
class CagnotteGuide {
  const CagnotteGuide({required this.mode, required this.summary, required this.steps, required this.example});

  final CagnotteMode mode;
  final String summary;
  final List<String> steps;
  final String example;
}

const cagnotteGuides = [
  CagnotteGuide(
    mode: CagnotteMode.solidarity,
    summary: 'Une collecte de durée limitée pour soutenir une personne, membre ou non de l’organisation.',
    steps: [
      'Le responsable choisit le bénéficiaire, la durée et la participation minimum.',
      'Chacun participe librement pendant le compte à rebours. Le trésorier enregistre, la personne confirme.',
      'À la clôture, le responsable remet les fonds et le bénéficiaire membre confirme la réception.',
    ],
    example: 'Un décès dans la famille d’une adhérente : une cagnotte de 7 jours réunit 180 000 FCFA pour les frais.',
  ),
  CagnotteGuide(
    mode: CagnotteMode.prize,
    summary: 'Chaque participation donne des tickets. À la clôture, des gagnants sont tirés au sort de façon vérifiable.',
    steps: [
      'Le responsable fixe le prix du ticket, le nombre de gagnants et la part de chacun.',
      'Chaque tranche du prix du ticket donne un ticket, donc une chance de plus.',
      'À la clôture, la liste des tickets et l’empreinte du tirage sont publiées, puis le tirage est révélé.',
      'Chaque gain remis est enregistré, puis confirmé par le gagnant.',
    ],
    example: 'Cagnotte Flash de 24 heures, ticket à 500 FCFA, 3 gagnants à 50 %, 30 % et 20 % de la somme réunie.',
  ),
];

CagnotteGuide cagnotteGuideFor(CagnotteMode mode) => cagnotteGuides.firstWhere((guide) => guide.mode == mode);

const feeExplanation = 'La commission est retenue sur la somme réunie avant le partage des gains. '
    'Elle est affichée à tous dès la création.';
