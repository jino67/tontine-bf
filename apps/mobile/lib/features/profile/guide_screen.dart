import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../content/tontine_guide.dart';
import '../../core/widgets/ui.dart';
import '../tontines/models.dart';

/// Guide des types de tontine. Ouvert depuis la création, il se place sur le type choisi.
class GuideScreen extends StatefulWidget {
  const GuideScreen({super.key, this.initialType});

  final TontineType? initialType;

  @override
  State<GuideScreen> createState() => _GuideScreenState();
}

class _GuideScreenState extends State<GuideScreen> {
  final _keys = {for (final type in TontineType.values) type: GlobalKey()};

  @override
  void initState() {
    super.initState();
    final initial = widget.initialType;
    if (initial == null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _keys[initial]?.currentContext;
      if (target == null || !mounted) return;
      Scrollable.ensureVisible(
        target,
        alignment: 0.02,
        duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 300),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Types de tontine')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Chaque type répond à un besoin différent. Tous se suivent de la même façon : '
              'le trésorier enregistre les paiements, les membres les confirment.',
              style: theme.textTheme.bodyLarge?.copyWith(color: AppColors.muted),
            ),
            const SizedBox(height: 20),
            for (final guide in tontineGuides)
              Padding(
                key: _keys[guide.type],
                padding: const EdgeInsets.only(bottom: 16),
                child: _GuideCard(guide: guide, highlighted: guide.type == widget.initialType),
              ),
            Panel(
              color: AppColors.goldSoft,
              borderColor: AppColors.goldSoft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Les parts', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 6),
                  Text(sharesExplanation, style: theme.textTheme.bodyMedium),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GuideCard extends StatelessWidget {
  const _GuideCard({required this.guide, required this.highlighted});

  final TontineGuide guide;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Panel(
      radius: 20,
      padding: const EdgeInsets.all(18),
      borderColor: highlighted ? AppColors.leaf : AppColors.line,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(color: AppColors.leafSoft, borderRadius: BorderRadius.circular(12)),
                child: Icon(guide.type.icon, color: AppColors.leafDeep),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(guide.type.label, style: theme.textTheme.titleLarge)),
            ],
          ),
          const SizedBox(height: 12),
          Text(guide.summary, style: theme.textTheme.bodyLarge),
          const SizedBox(height: 16),
          Text('Comment ça se passe', style: theme.textTheme.titleSmall),
          const SizedBox(height: 10),
          for (var i = 0; i < guide.steps.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(color: AppColors.leafSoft, shape: BoxShape.circle),
                    child: Text('${i + 1}', style: AppType.sans(size: 13, bold: true, color: AppColors.leafDeep, height: 1)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(guide.steps[i], style: theme.textTheme.bodyMedium)),
                ],
              ),
            ),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: AppColors.cotton, borderRadius: BorderRadius.circular(12)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Exemple', style: AppType.sans(size: 14, bold: true, color: AppColors.goldText)),
                const SizedBox(height: 4),
                Text(guide.example, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: 'Adapté à : ', style: AppType.sans(size: 15, bold: true)),
                TextSpan(text: guide.suitedFor),
              ],
            ),
            style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}
