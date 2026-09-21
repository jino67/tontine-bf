import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/session/session_scope.dart';
import '../../core/widgets/ui.dart';
import 'fees.dart';
import 'fees_repository.dart';

/// Ce que l'application prélève, opération par opération.
///
/// Cette page existe pour être montrée : un membre qui doute des frais doit pouvoir les lire
/// en entier, sans avoir à demander à qui que ce soit.
class FeesScreen extends StatefulWidget {
  const FeesScreen({super.key});

  @override
  State<FeesScreen> createState() => _FeesScreenState();
}

class _FeesScreenState extends State<FeesScreen> {
  late Future<FeeGrid> _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final session = SessionScope.read(context);
    _future = FeesRepository(session.api, organizationId: session.currentOrganization?.id).grid();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Frais de service')),
      body: FutureBuilder<FeeGrid>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.hasError && !snapshot.hasData) {
            return ErrorView(error: snapshot.error!, onRetry: () => setState(() {}));
          }
          if (!snapshot.hasData) return const LoadingView();

          final grid = snapshot.requireData;

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              Panel(
                color: AppColors.leafSoft,
                borderColor: AppColors.leafSoft,
                child: Text(grid.note, style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.leafDeep)),
              ),
              const SizedBox(height: 16),
              for (final line in grid.lines)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _FeeTile(line: line),
                ),
              const SizedBox(height: 8),
              Text(
                'Ces frais couvrent ce que l’encaissement coûte à l’application, et ce qui la fait '
                'vivre. Ils sont toujours annoncés avant une confirmation : si un montant vous '
                'surprend, c’est une erreur, signalez-la.',
                style: theme.textTheme.bodySmall?.copyWith(color: AppColors.muted),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _FeeTile extends StatelessWidget {
  const _FeeTile({required this.line});

  final FeeLine line;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Text(line.label, style: AppType.sans(bold: true))),
              const SizedBox(width: 12),
              StatusPill(label: line.detail, tone: line.isFree ? Tone.positive : Tone.neutral),
            ],
          ),
          const SizedBox(height: 6),
          Text(line.description, style: theme.textTheme.bodySmall?.copyWith(color: AppColors.muted)),
          if (!line.isFree)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                line.deducted
                    ? 'Retenus sur la somme remise, payés par ${line.payerLabel}.'
                    : 'Ajoutés au montant, payés par ${line.payerLabel}.',
                style: theme.textTheme.bodySmall?.copyWith(color: AppColors.muted),
              ),
            ),
        ],
      ),
    );
  }
}
