import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/api/api_exception.dart';
import '../../core/format.dart';
import '../../core/json.dart';
import '../../core/session/session_controller.dart';
import '../../core/session/session_scope.dart';
import '../../core/widgets/brand.dart';
import '../../core/widgets/ui.dart';
import '../discover/discover_repository.dart';
import '../discover/join_request.dart';
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

  /// Demande d'adhésion. Quand l'adhésion est libre, l'API fait entrer tout de suite.
  Future<void> _request(SharedLink link) async {
    final id = link.objectId;
    if (id == null) return;

    final session = SessionScope.read(context);
    final messenger = ScaffoldMessenger.of(context);

    setState(() => _joining = true);
    try {
      final request = await DiscoverRepository(session.api).requestJoin(
        type: link.type == 'organisation' ? 'organisation' : 'tontine',
        id: id,
      );
      if (request == null) await session.reloadOrganizations();
      if (!mounted) return;
      setState(() {
        _joining = false;
        _future = _resolve();
      });
      messenger.showSnackBar(SnackBar(
        content: Text(request == null ? 'Vous en faites maintenant partie.' : 'Demande envoyée au responsable.'),
      ));
    } catch (error) {
      if (!mounted) return;
      setState(() => _joining = false);
      showError(context, error);
    }
  }

  Future<void> _report(SharedLink link) async {
    final id = link.objectId;
    if (id == null) return;

    final reason = await showModalBottomSheet<ReportReason>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
              child: Text('Pourquoi signaler cette page ?', style: Theme.of(context).textTheme.titleLarge),
            ),
            for (final reason in ReportReason.values)
              ListTile(title: Text(reason.label), onTap: () => Navigator.of(context).pop(reason)),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (reason == null || !mounted) return;

    try {
      await DiscoverRepository(SessionScope.read(context).api).report(type: link.type, id: id, reason: reason);
      if (mounted) showDone(context, 'Signalement envoyé. Merci.');
    } catch (error) {
      if (mounted) showError(context, error);
    }
  }

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

    if (session.status != SessionStatus.signedIn) {
      return [
        Text(
          'Connectez-vous avec votre numéro pour demander à rejoindre.',
          style: theme.textTheme.bodyLarge?.copyWith(color: AppColors.muted),
        ),
      ];
    }

    if (link.isMember) {
      return [
        Text('Vous en faites déjà partie.', style: theme.textTheme.bodyLarge?.copyWith(color: AppColors.muted)),
        ..._reportAction(link),
      ];
    }

    if (link.hasPendingRequest) {
      return [
        Text(
          'Votre demande est en attente. Le responsable vous répondra dans l’application.',
          style: theme.textTheme.bodyLarge?.copyWith(color: AppColors.muted),
        ),
        ..._reportAction(link),
      ];
    }

    if (link.type != 'cagnotte' && link.acceptsRequests) {
      return [
        FilledButton(
          onPressed: _joining ? null : () => _request(link),
          child: _joining ? const ButtonSpinner() : const Text('Demander à rejoindre'),
        ),
        const SizedBox(height: 8),
        Text(
          'Le responsable accepte ou refuse. Rien ne vous engage tant qu’il n’a pas répondu.',
          style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.muted),
        ),
        ..._reportAction(link),
      ];
    }

    return [
      Text(
        link.type == 'cagnotte'
            ? 'Rejoignez l’organisation pour participer à cette cagnotte.'
            : 'Cette page se rejoint sur invitation. Demandez son code au responsable.',
        style: theme.textTheme.bodyLarge?.copyWith(color: AppColors.muted),
      ),
      ..._reportAction(link),
    ];
  }

  /// Signaler n'a de sens que sur une fiche publique d'objet, pas sur une invitation reçue.
  List<Widget> _reportAction(SharedLink link) {
    if (link.type != 'tontine' && link.type != 'cagnotte') return const [];

    return [
      const SizedBox(height: 12),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: () => _report(link),
          icon: const Icon(Icons.flag_outlined, size: 18),
          label: const Text('Signaler'),
        ),
      ),
    ];
  }
}
