import 'package:flutter/material.dart';

import '../../app/config.dart';
import '../../app/theme.dart';
import '../../content/legal.dart';
import '../../core/widgets/brand.dart';
import '../../core/widgets/ui.dart';
import '../../core/widgets/woven_band.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Confidentialité')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        children: [
          Panel(
            color: AppColors.goldSoft,
            borderColor: AppColors.goldSoft,
            padding: const EdgeInsets.all(14),
            child: Text(privacyDraftNotice, style: theme.textTheme.bodyMedium),
          ),
          for (final section in privacySections) ...[
            const SizedBox(height: 26),
            Text(section.title, style: theme.textTheme.titleLarge),
            const SizedBox(height: 10),
            for (final paragraph in section.paragraphs)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      margin: const EdgeInsets.only(top: 9),
                      decoration: const BoxDecoration(color: AppColors.leaf, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text(paragraph, style: theme.textTheme.bodyLarge)),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        children: [
          Row(
            children: [
              const AppLogo(size: 60),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(AppConfig.appName, style: theme.textTheme.headlineMedium),
                    Text('Version ${AppConfig.version}', style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          WovenBand(
            height: 18,
            semanticLabel: 'Motif de bande tissée',
            segments: progressSegments(0.7, 8, color: AppColors.gold),
          ),
          const SizedBox(height: 24),
          for (final paragraph in aboutParagraphs)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Text(paragraph, style: theme.textTheme.bodyLarge),
            ),
          const SizedBox(height: 10),
          Text('Typographie', style: theme.textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(
            'Titres en Young Serif, textes en Atkinson Hyperlegible, une police conçue pour rester lisible '
            'quand la vue ou l’écran fatiguent. Les deux sont publiées sous licence SIL Open Font License.',
            style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.muted),
          ),
          const SizedBox(height: 20),
          OutlinedButton(
            onPressed: () => showLicensePage(
              context: context,
              applicationName: AppConfig.appName,
              applicationVersion: AppConfig.version,
            ),
            child: const Text('Licences des composants'),
          ),
        ],
      ),
    );
  }
}
