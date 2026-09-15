import 'package:flutter/material.dart';

import '../../app/config.dart';
import '../../app/theme.dart';
import '../../content/help.dart';
import '../../core/widgets/ui.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Questions fréquentes')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Les réponses aux questions que se posent le plus souvent les membres et les trésoriers.',
              style: theme.textTheme.bodyLarge?.copyWith(color: AppColors.muted),
            ),
          ),
          for (final topic in helpTopics) ...[
            SectionTitle(topic.title),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Card(
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    for (var i = 0; i < topic.questions.length; i++) ...[
                      if (i > 0) const Divider(),
                      ExpansionTile(
                        title: Text(topic.questions[i].question, style: theme.textTheme.titleSmall),
                        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        expandedAlignment: Alignment.centerLeft,
                        children: [Text(topic.questions[i].answer, style: theme.textTheme.bodyLarge)],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
            child: Panel(
              color: AppColors.goldSoft,
              borderColor: AppColors.goldSoft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Vous ne trouvez pas la réponse ?', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    AppConfig.supportEmail.isEmpty
                        ? 'Posez la question au responsable ou au trésorier de votre organisation.'
                        : 'Posez la question au responsable de votre organisation, ou écrivez-nous à ${AppConfig.supportEmail}.',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
