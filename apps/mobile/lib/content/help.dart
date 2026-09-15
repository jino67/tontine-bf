/// Questions fréquentes, regroupées par thème.
class HelpTopic {
  const HelpTopic({required this.title, required this.questions});

  final String title;
  final List<HelpQuestion> questions;
}

class HelpQuestion {
  const HelpQuestion(this.question, this.answer);

  final String question;
  final String answer;
}

const helpTopics = [
  HelpTopic(
    title: 'Connexion',
    questions: [
      HelpQuestion(
        'Je ne reçois pas le code par SMS',
        'Vérifiez que le numéro saisi est bien le vôtre, puis patientez une minute. '
            'Vous pouvez demander 3 codes par tranche de 10 minutes. Un code reste valable 10 minutes.',
      ),
      HelpQuestion(
        'J’ai changé de téléphone',
        'Installez l’application et connectez-vous avec le même numéro : vos organisations et vos tontines vous attendent.',
      ),
      HelpQuestion(
        'J’ai changé de numéro',
        'Demandez au responsable de votre organisation de vous inviter avec votre nouveau numéro.',
      ),
    ],
  ),
  HelpTopic(
    title: 'Cotisations',
    questions: [
      HelpQuestion(
        'Comment payer ma cotisation ?',
        'Comme d’habitude : en espèces ou par Orange Money ou Moov Money, auprès du trésorier. '
            'L’application ne prélève rien. Le trésorier enregistre votre paiement, puis vous le confirmez.',
      ),
      HelpQuestion(
        'Pourquoi dois-je confirmer mon paiement ?',
        'La confirmation prouve que vous et le trésorier êtes d’accord sur le montant. '
            'Une fois confirmée, la cotisation ne peut plus être modifiée par personne.',
      ),
      HelpQuestion(
        'Le montant enregistré est faux',
        'Ne le confirmez pas et prévenez le trésorier. Tant que vous n’avez pas confirmé, il peut le corriger.',
      ),
      HelpQuestion(
        'Que signifie « en retard » ?',
        'L’échéance du tour est passée et votre cotisation n’a pas été enregistrée en entier.',
      ),
    ],
  ),
  HelpTopic(
    title: 'Tontines',
    questions: [
      HelpQuestion(
        'Qu’est-ce qu’une part ?',
        'Une part correspond à une cotisation par tour. Avec deux parts, vous cotisez le double et recevez la cagnotte deux fois.',
      ),
      HelpQuestion(
        'Je ne vois pas toutes les tontines de mon organisation',
        'Un membre voit uniquement les tontines auxquelles il participe. Le trésorier et les responsables les voient toutes.',
      ),
      HelpQuestion(
        'Puis-je rejoindre une tontine déjà démarrée ?',
        'Non. Les inscriptions se ferment au démarrage, car les tours et les montants sont alors calculés pour tous les membres.',
      ),
    ],
  ),
  HelpTopic(
    title: 'Tirage au sort',
    questions: [
      HelpQuestion(
        'Comment savoir que le tirage n’est pas arrangé ?',
        'Au lancement, l’application publie l’empreinte d’une graine secrète. La graine n’est révélée qu’après la date annoncée. '
            'Votre téléphone vérifie alors que la graine correspond à l’empreinte et recalcule lui-même le résultat.',
      ),
      HelpQuestion(
        'Le responsable peut-il choisir qui passe ou qui gagne ?',
        'Oui, mais jamais en secret. Un tour attribué est publié à tous au lancement du tirage. Un gain attribué est affiché '
            'avec le nom du membre avant la première participation, puis il ne peut plus changer. Tout le reste est tiré au sort.',
      ),
      HelpQuestion(
        'Qui peut révéler le tirage ?',
        'N’importe quel membre, une fois la date de révélation passée. Le responsable ne peut pas le faire plus tôt.',
      ),
    ],
  ),
  HelpTopic(
    title: 'Cagnottes',
    questions: [
      HelpQuestion(
        'Quelle différence entre les deux cagnottes ?',
        'La cagnotte solidaire réunit de l’argent pour une personne, membre ou non. La cagnotte à gagnants donne des tickets '
            'à chaque participation, puis des gagnants sont tirés au sort à la clôture.',
      ),
      HelpQuestion(
        'Combien de tickets ai-je ?',
        'Un ticket par tranche complète du prix du ticket. Avec un ticket à 500 FCFA, une participation de 1 200 FCFA donne 2 tickets.',
      ),
      HelpQuestion(
        'Que se passe-t-il à la fin du compte à rebours ?',
        'La cagnotte se ferme toute seule : plus aucune participation n’est acceptée. Le responsable remet alors les fonds, '
            'ou lance le tirage des gagnants.',
      ),
      HelpQuestion(
        'Comment les gains sont-ils calculés ?',
        'La commission éventuelle, affichée dès la création, est retenue sur la somme réunie. Le reste est partagé selon le '
            'pourcentage de chaque rang. S’il y a moins de gagnants que de rangs, tout est réparti entre les gagnants.',
      ),
    ],
  ),
  HelpTopic(
    title: 'Rôles et confidentialité',
    questions: [
      HelpQuestion(
        'Qui voit mon numéro de téléphone ?',
        'Vous, le trésorier et les responsables de l’organisation. Les autres membres voient un numéro masqué.',
      ),
      HelpQuestion(
        'Quels sont les rôles ?',
        'Le propriétaire gère l’organisation et attribue les rôles. Les responsables créent les tontines et invitent. '
            'Le trésorier enregistre les paiements. Les membres cotisent et confirment leurs paiements.',
      ),
      HelpQuestion(
        'L’application garde-t-elle mon argent ?',
        'Non. Aucun argent ne transite par Tontine BF : l’application enregistre et vérifie, elle ne détient aucun fonds.',
      ),
    ],
  ),
];
