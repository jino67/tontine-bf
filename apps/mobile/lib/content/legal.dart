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
    'Votre nom et votre adresse e-mail, qui sert aussi à recevoir le code de connexion.',
    'Les organisations et tontines dont vous êtes membre, et les cotisations enregistrées à votre nom.',
  ]),
  LegalSection('Pourquoi', [
    'Pour vous identifier, suivre les cotisations et permettre à votre organisation de gérer ses tontines.',
    'Vos données ne sont ni vendues ni utilisées pour de la publicité.',
  ]),
  LegalSection('Qui y a accès', [
    'Les responsables et le trésorier de votre organisation voient votre nom, votre numéro et vos cotisations.',
    'Les autres membres voient votre nom et un numéro masqué.',
    'Pour un paiement ou une remise en ligne, PayDunya reçoit le montant et le numéro mobile money utilisé.',
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
  'Les paiements en espèces sont enregistrés par le trésorier et confirmés par chaque membre. '
      'Les paiements en ligne passent par PayDunya et sont confirmés automatiquement.',
  'Les tirages au sort sont vérifiables par tous : une fois l’empreinte publiée, personne, pas même l’équipe de Tontine BF, '
      'ne peut en changer le résultat.',
  'Quand un responsable attribue lui-même un tour ou un gain, ce choix est affiché à tous les membres avant qu’ils ne paient, '
      'puis il ne peut plus être modifié.',
];
