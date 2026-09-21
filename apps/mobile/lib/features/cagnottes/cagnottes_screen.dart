import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../content/cagnotte_guide.dart';
import '../../core/session/session_scope.dart';
import '../../core/widgets/ui.dart';
import '../discover/discover_screen.dart';
import 'cagnotte.dart';
import 'cagnotte_repository.dart';
import 'cagnotte_tile.dart';
import 'create_cagnotte_screen.dart';

enum _Filter {
  all('Toutes'),
  open('Ouvertes'),
  finished('Terminées');

  const _Filter(this.label);

  final String label;

  bool matches(Cagnotte cagnotte) => switch (this) {
        _Filter.all => true,
        _Filter.open => cagnotte.isOpen,
        _Filter.finished => !cagnotte.isOpen,
      };
}

class CagnottesScreen extends StatefulWidget {
  const CagnottesScreen({super.key, required this.repository});

  final CagnotteRepository repository;

  @override
  State<CagnottesScreen> createState() => _CagnottesScreenState();
}

class _CagnottesScreenState extends State<CagnottesScreen> {
  late Future<List<Cagnotte>> _future;
  _Filter _filter = _Filter.all;

  @override
  void initState() {
    super.initState();
    _future = widget.repository.list();
    widget.repository.revision.addListener(_refresh);
  }

  @override
  void dispose() {
    widget.repository.revision.removeListener(_refresh);
    super.dispose();
  }

  Future<void> _refresh() async {
    final future = widget.repository.list();
    setState(() => _future = future);
    try {
      await future;
    } catch (_) {
      // L'erreur est affichée à l'écran.
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = SessionScope.of(context).currentOrganization!.role;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cagnottes'),
        actions: [
          IconButton(
            tooltip: 'Découvrir des cagnottes publiques',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DiscoverScreen())),
            icon: const Icon(Icons.travel_explore_rounded),
          ),
        ],
      ),
      floatingActionButton: role.canManage
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => CreateCagnotteScreen(repository: widget.repository)),
              ),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Nouvelle cagnotte'),
            )
          : null,
      body: FutureBuilder<List<Cagnotte>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.hasError && !snapshot.hasData) return ErrorView(error: snapshot.error!, onRetry: _refresh);
          if (!snapshot.hasData) return const LoadingView();

          final all = snapshot.requireData;
          final visible = all.where(_filter.matches).toList();

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 96),
              children: [
                if (all.isNotEmpty) ...[
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final filter in _Filter.values)
                        ChoiceChip(
                          label: Text(filter.label),
                          selected: _filter == filter,
                          showCheckmark: false,
                          onSelected: (_) => setState(() => _filter = filter),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
                if (all.isEmpty) ...[
                  Text('Aucune cagnotte pour le moment', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text(
                    role.canManage
                        ? 'Touchez « Nouvelle cagnotte » pour ouvrir une collecte à durée limitée.'
                        : 'Les cagnottes ouvertes par votre organisation apparaîtront ici.',
                    style: theme.textTheme.bodyLarge?.copyWith(color: AppColors.muted),
                  ),
                  const SizedBox(height: 20),
                  for (final guide in cagnotteGuides)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _GuideCard(guide: guide),
                    ),
                ] else if (visible.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 40),
                    child: Text('Aucune cagnotte dans cette catégorie', textAlign: TextAlign.center, style: theme.textTheme.titleLarge),
                  )
                else
                  for (final cagnotte in visible)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: CagnotteTile(cagnotte: cagnotte, repository: widget.repository),
                    ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _GuideCard extends StatelessWidget {
  const _GuideCard({required this.guide});

  final CagnotteGuide guide;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Panel(
      radius: 20,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(guide.mode.icon, color: AppColors.leafDeep),
              const SizedBox(width: 10),
              Expanded(child: Text(guide.mode.label, style: theme.textTheme.titleLarge)),
            ],
          ),
          const SizedBox(height: 8),
          Text(guide.summary, style: theme.textTheme.bodyLarge),
          const SizedBox(height: 12),
          for (var i = 0; i < guide.steps.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text('${i + 1}. ${guide.steps[i]}', style: theme.textTheme.bodyMedium),
            ),
          const SizedBox(height: 4),
          Text(guide.example, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}
