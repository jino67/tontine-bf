/// Écrans de présentation affichés au premier lancement.
class OnboardingPage {
  const OnboardingPage({required this.title, required this.body, required this.fills});

  final String title;
  final String body;

  /// Remplissage de la bande tissée qui illustre la page.
  final List<double> fills;
}

const onboardingPages = [
  OnboardingPage(
    title: 'Votre tontine, sans le cahier',
    body: 'Cotisations, tours de passage et retards sont suivis au même endroit, '
        'par le trésorier comme par chaque membre.',
    fills: [1, 1, 0.6, 0, 0, 0],
  ),
  OnboardingPage(
    title: 'Chaque franc est tracé',
    body: 'Le trésorier enregistre le paiement, puis le membre le confirme. '
        'Une cotisation confirmée ne peut plus être modifiée.',
    fills: [1, 1, 1, 1, 0.5, 0],
  ),
  OnboardingPage(
    title: "Un tirage que personne ne peut arranger",
    body: "L'ordre de passage peut être tiré au sort de façon vérifiable : "
        'chaque membre recalcule le résultat sur son propre téléphone.',
    fills: [1, 1, 1, 1, 1, 1],
  ),
];

const onboardingMoneyNote = "Tontine BF ne garde pas votre argent. Les cotisations se paient comme d'habitude, "
    'en espèces ou par mobile money. L’application sert à les suivre.';
