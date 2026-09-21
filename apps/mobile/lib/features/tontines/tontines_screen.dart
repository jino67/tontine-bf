import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/session/session_scope.dart';
import '../../core/widgets/ui.dart';
import '../discover/discover_screen.dart';
import 'create_tontine_screen.dart';
import 'models.dart';
import 'tontine_repository.dart';
import 'tontine_tile.dart';

enum _Filter {
  all('Toutes'),
  draft('Inscriptions ouvertes'),
  active('En cours'),
  closed('Terminées');

  const _Filter(this.label);

  final String label;

  bool matches(Tontine tontine) => switch (this) {
        _Filter.all => true,
        _Filter.draft => tontine.isDraft,
        _Filter.active => tontine.isActive,
        _Filter.closed => tontine.status == TontineStatus.completed || tontine.status == TontineStatus.cancelled,
      };
}

class TontinesScreen extends StatefulWidget {
  const TontinesScreen({super.key, required this.repository});

  final TontineRepository repository;

  @override
  State<TontinesScreen> createState() => _TontinesScreenState();
}

class _TontinesScreenState extends State<TontinesScreen> {
  late Future<List<Tontine>> _future;
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
        title: const Text('Tontines'),
        actions: [
          IconButton(
            tooltip: 'Découvrir des tontines publiques',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DiscoverScreen())),
            icon: const Icon(Icons.travel_explore_rounded),
          ),
        ],
      ),
      floatingActionButton: role.canManage
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => CreateTontineScreen(repository: widget.repository)),
              ),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Nouvelle tontine'),
            )
          : null,
      body: FutureBuilder<List<Tontine>>(
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
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final filter in _Filter.values) ...[
                        ChoiceChip(
                          label: Text(filter.label),
                          selected: _filter == filter,
                          showCheckmark: false,
                          onSelected: (_) => setState(() => _filter = filter),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (visible.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 40),
                    child: Column(
                      children: [
                        Text(
                          all.isEmpty ? 'Aucune tontine pour le moment' : 'Aucune tontine dans cette catégorie',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          all.isEmpty && role.canManage
                              ? 'Touchez « Nouvelle tontine » pour créer la première.'
                              : all.isEmpty
                                  ? 'Les tontines auxquelles vous participez apparaîtront ici.'
                                  : 'Choisissez un autre filtre pour voir les autres tontines.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyLarge?.copyWith(color: AppColors.muted),
                        ),
                      ],
                    ),
                  )
                else
                  for (final tontine in visible)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: TontineTile(tontine: tontine, repository: widget.repository),
                    ),
              ],
            ),
          );
        },
      ),
    );
  }
}
