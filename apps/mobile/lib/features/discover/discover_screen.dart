import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/format.dart';
import '../../core/json.dart';
import '../../core/session/session_scope.dart';
import '../../core/widgets/ui.dart';
import '../sharing/link_screen.dart';
import '../sharing/sharing.dart';
import 'discover_repository.dart';

/// Annuaire public : tontines ouvertes aux demandes et cagnottes visibles de tous.
class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  final _query = TextEditingController();
  late DiscoverRepository _repository;
  late Future<DiscoverResults> _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _repository = DiscoverRepository(SessionScope.read(context).api);
    _future = _repository.search();
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  void _search() => setState(() => _future = _repository.search(query: _query.text));

  void _open(SharedLink link) {
    final code = shareCodeFrom(asStringOrNull(link.data['share_url']) ?? '');
    if (code == null) return;

    Navigator.of(context).push(MaterialPageRoute(builder: (_) => LinkScreen(code: code)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Découvrir')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: TextField(
              controller: _query,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _search(),
              decoration: InputDecoration(
                hintText: 'Chercher une tontine ou une cagnotte',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: IconButton(icon: const Icon(Icons.arrow_forward_rounded), onPressed: _search),
              ),
            ),
          ),
          Expanded(
            child: FutureBuilder<DiscoverResults>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.hasError) return ErrorView(error: snapshot.error!, onRetry: _search);
                if (!snapshot.hasData) return const LoadingView();

                final results = snapshot.requireData;

                if (results.isEmpty) {
                  return const MessageView(
                    icon: Icons.travel_explore_rounded,
                    title: 'Rien pour l’instant',
                    message: 'Aucune tontine ni cagnotte publique ne correspond. Essayez un autre mot, ou revenez plus tard.',
                  );
                }

                return ListView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                  children: [
                    if (results.tontines.isNotEmpty) ...[
                      Text('Tontines ouvertes', style: theme.textTheme.titleSmall),
                      const SizedBox(height: 8),
                      for (final tontine in results.tontines)
                        _Card(
                          title: tontine.title,
                          subtitle: '${fcfa(asInt(tontine.data['amount']))} ${_frequency(tontine.data['frequency'])}',
                          detail: _places(tontine),
                          organization: tontine.organizationName,
                          icon: Icons.groups_2_outlined,
                          onTap: () => _open(tontine),
                        ),
                      const SizedBox(height: 18),
                    ],
                    if (results.cagnottes.isNotEmpty) ...[
                      Text('Cagnottes en cours', style: theme.textTheme.titleSmall),
                      const SizedBox(height: 8),
                      for (final cagnotte in results.cagnottes)
                        _Card(
                          title: cagnotte.title,
                          subtitle: '${fcfa(asInt(cagnotte.data['collected_amount']))} réunis',
                          detail: countLabel(asInt(cagnotte.data['contributions_count']), 'participation', 'participations'),
                          organization: cagnotte.organizationName,
                          icon: Icons.volunteer_activism_outlined,
                          onTap: () => _open(cagnotte),
                        ),
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _frequency(Object? value) => switch ('$value') {
        'quotidien' => 'par jour',
        'mensuel' => 'par mois',
        _ => 'par semaine',
      };

  String _places(SharedLink tontine) {
    final left = asIntOrNull(tontine.data['places_left']);
    final members = asInt(tontine.data['members_count']);

    return left == null ? countLabel(members, 'membre', 'membres') : '$left place(s) restante(s)';
  }
}

class _Card extends StatelessWidget {
  const _Card({
    required this.title,
    required this.subtitle,
    required this.detail,
    required this.icon,
    required this.onTap,
    this.organization,
  });

  final String title;
  final String subtitle;
  final String detail;
  final String? organization;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(backgroundColor: AppColors.leafSoft, child: Icon(icon, color: AppColors.leafDeep)),
        title: Text(title, style: theme.textTheme.titleSmall),
        subtitle: Text(
          [subtitle, detail, if (organization != null) organization!].join(' · '),
          style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.muted),
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      ),
    );
  }
}
