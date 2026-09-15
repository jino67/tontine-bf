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
    title: 'Des tirages vérifiables par tous',
    body: "Ordre de passage et gagnants des cagnottes : chaque membre recalcule le résultat sur son téléphone. "
        'Un tour ou un gain attribué par le responsable est affiché à tous, à l’avance.',
    fills: [1, 1, 1, 1, 1, 1],
  ),
];

const onboardingMoneyNote = 'Payez en espèces auprès du trésorier, ou en ligne par Orange Money, Moov Money ou carte '
    'grâce à PayDunya. Un paiement en ligne est confirmé automatiquement.';
