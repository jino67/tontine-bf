/// Textes d'information. La politique de confidentialité définitive doit être validée par un juriste
/// avant la mise en production (voir docs/GUIDE_SAAS.md, section 2.6).
class LegalSection {
  const LegalSection(this.title, this.paragraphs);

  final String title;
  final List<String> paragraphs;
}

const privacyDraftNotice = 'Résumé provisoire. La politique de confidentialité complète sera publiée avant l’ouverture du service.';

const privacySections = [
  LegalSection('Ce que nous enregistrons', [
    'Votre numéro de téléphone, qui sert à vous connecter.',
    'Votre nom et, si vous le donnez, votre adresse e-mail.',
    'Les organisations et tontines dont vous êtes membre, et les cotisations enregistrées à votre nom.',
  ]),
  LegalSection('Pourquoi', [
    'Pour vous identifier, suivre les cotisations et permettre à votre organisation de gérer ses tontines.',
    'Vos données ne sont ni vendues ni utilisées pour de la publicité.',
  ]),
  LegalSection('Qui y a accès', [
    'Les responsables et le trésorier de votre organisation voient votre nom, votre numéro et vos cotisations.',
    'Les autres membres voient votre nom et un numéro masqué.',
  ]),
  LegalSection('Vos droits', [
    'Au Burkina Faso, la loi n°001-2021/AN protège vos données personnelles, sous le contrôle de la CIL.',
    'Vous pouvez demander à consulter, corriger ou supprimer vos données. '
        'Les cotisations déjà confirmées sont conservées tant que la tontine l’exige.',
  ]),
];

const aboutParagraphs = [
  'Tontine BF aide les associations, groupements et coopératives à tenir leurs tontines sans cahier : '
      'qui a cotisé, qui reçoit, qui est en retard.',
  'L’application ne détient pas d’argent. Elle enregistre ce que le trésorier reçoit et le fait confirmer par chaque membre.',
  'Le tirage au sort de l’ordre de passage est vérifiable par tous : personne, pas même l’équipe de Tontine BF, ne peut en choisir le résultat.',
];
