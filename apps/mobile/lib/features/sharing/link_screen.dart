import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/api/api_exception.dart';
import '../../core/format.dart';
import '../../core/json.dart';
import '../../core/session/session_controller.dart';
import '../../core/session/session_scope.dart';
import '../../core/widgets/brand.dart';
import '../../core/widgets/ui.dart';
import 'sharing.dart';
import 'sharing_repository.dart';

/// Écran ouvert par un lien partagé : la fiche publique, puis ce qu'il est possible de faire.
class LinkScreen extends StatefulWidget {
  const LinkScreen({super.key, required this.code});

  final String code;

  @override
  State<LinkScreen> createState() => _LinkScreenState();
}

class _LinkScreenState extends State<LinkScreen> {
  late Future<SharedLink> _future = _resolve();
  bool _joining = false;

  Future<SharedLink> _resolve() => SharingRepository(SessionScope.read(context).api).resolve(widget.code);

  Future<void> _join(SharedLink link) async {
    final session = SessionScope.read(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    setState(() => _joining = true);
    try {
      final result = await session.organizations.acceptInvitation(link.invitationCode ?? widget.code);
      await session.reloadOrganizations(select: result.organization.id);
      if (navigator.canPop()) navigator.pop();
      final tontine = result.tontineName == null ? '' : ' et à la tontine ${result.tontineName}';
      messenger.showSnackBar(SnackBar(content: Text('Bienvenue dans ${result.organization.name}$tontine.')));
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _joining = false);
      showError(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: FutureBuilder<SharedLink>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return ErrorView(error: snapshot.error!, onRetry: () => setState(() => _future = _resolve()));
            }
            if (!snapshot.hasData) return const LoadingView();

            final link = snapshot.requireData;

            return ListView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
              children: [
                Text(_kind(link), style: AppType.sans(size: 14, bold: true, color: AppColors.muted)),
                const SizedBox(height: 6),
                Text(link.title, style: theme.textTheme.headlineMedium),
                if (link.organizationName != null) ...[
                  const SizedBox(height: 4),
                  Text(link.organizationName!, style: theme.textTheme.bodyLarge?.copyWith(color: AppColors.muted)),
                ],
                const SizedBox(height: 20),
                Panel(
                  child: Column(
                    children: [
                      for (final line in _lines(link))
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(line.$1, style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.muted)),
                              Text(line.$2, style: AppType.sans(bold: true)),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                ..._actions(link),
              ],
            );
          },
        ),
      ),
    );
  }

  String _kind(SharedLink link) => switch (link.type) {
        'tontine' => 'TONTINE',
        'cagnotte' => 'CAGNOTTE',
        'organisation' => 'ORGANISATION',
        _ => 'INVITATION',
      };

  /// Libellé et valeur de chaque ligne de la fiche.
  List<(String, String)> _lines(SharedLink link) {
    final data = link.data;

    return switch (link.type) {
      'tontine' => [
          ('Cotisation', '${fcfa(asInt(data['amount']))} ${_frequency(data['frequency'])}'),
          ('Membres', '${asInt(data['members_count'])}'),
          if (asIntOrNull(data['places_left']) != null) ('Places restantes', '${asInt(data['places_left'])}'),
          ('État', data['started'] == true ? 'Déjà démarrée' : 'Pas encore démarrée'),
          if (asStringOrNull(data['creator']) != null) ('Créée par', '${data['creator']}'),
        ],
      'cagnotte' => [
          ('Réunis', fcfa(asInt(data['collected_amount']))),
          if (asIntOrNull(data['target_amount']) != null) ('Objectif', fcfa(asInt(data['target_amount']))),
          if (asIntOrNull(data['ticket_price']) != null) ('Ticket', fcfa(asInt(data['ticket_price']))),
          if (asIntOrNull(data['winners_count']) != null) ('Gagnants', '${asInt(data['winners_count'])}'),
          ('Participations', '${asInt(data['contributions_count'])}'),
          ('Fin', shortDate((asDate(data['ends_at']) ?? DateTime.now()).toLocal())),
        ],
      'organisation' => [
          ('Membres', '${asInt(data['members_count'])}'),
        ],
      _ => [
          if (asStringOrNull(data['tontine']) != null) ('Tontine', '${data['tontine']}'),
          ('Organisation', '${data['organization']}'),
          if (asDate(data['expires_at']) != null) ('Valable jusqu’au', shortDate(asDate(data['expires_at'])!.toLocal())),
        ],
    };
  }

  String _frequency(Object? value) => switch ('$value') {
        'quotidien' => 'par jour',
        'mensuel' => 'par mois',
        _ => 'par semaine',
      };

  List<Widget> _actions(SharedLink link) {
    final session = SessionScope.of(context);
    final theme = Theme.of(context);

    if (link.isInvitation) {
      if (!link.usable) {
        return [
          Text(
            'Cette invitation a expiré ou a déjà servi. Demandez-en une nouvelle au responsable.',
            style: theme.textTheme.bodyLarge?.copyWith(color: AppColors.chili),
          ),
        ];
      }
      if (session.status != SessionStatus.signedIn) {
        return [
          Text(
            'Connectez-vous avec votre numéro, puis rouvrez ce lien pour rejoindre.',
            style: theme.textTheme.bodyLarge?.copyWith(color: AppColors.muted),
          ),
        ];
      }

      return [
        FilledButton(
          onPressed: _joining ? null : () => _join(link),
          child: _joining ? const ButtonSpinner() : const Text('Rejoindre'),
        ),
      ];
    }

    return [
      Text(
        link.acceptsRequests
            ? 'Pour participer, demandez le code d’invitation au responsable. La demande d’adhésion directe arrive bientôt.'
            : 'Cette page se rejoint sur invitation. Demandez son code au responsable.',
        style: theme.textTheme.bodyLarge?.copyWith(color: AppColors.muted),
      ),
    ];
  }
}
