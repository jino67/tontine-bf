import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/format.dart';
import '../../core/session/session_scope.dart';
import '../../core/widgets/brand.dart';
import '../../core/widgets/ui.dart';
import 'discover_repository.dart';
import 'join_request.dart';

/// File des demandes d'adhésion, côté responsables.
class JoinRequestsScreen extends StatefulWidget {
  const JoinRequestsScreen({super.key, required this.organizationId});

  final int organizationId;

  @override
  State<JoinRequestsScreen> createState() => _JoinRequestsScreenState();
}

class _JoinRequestsScreenState extends State<JoinRequestsScreen> {
  late DiscoverRepository _repository;
  late Future<List<JoinRequestSummary>> _future;
  int? _busyId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _repository = DiscoverRepository(SessionScope.read(context).api);
    _future = _repository.pending(widget.organizationId);
  }

  Future<void> _refresh() async {
    final future = _repository.pending(widget.organizationId);
    setState(() => _future = future);
    try {
      await future;
    } catch (_) {
      // L'erreur est affichée à l'écran.
    }
  }

  Future<void> _decide(JoinRequestSummary request, {required bool accept}) async {
    final reason = accept ? null : await _askReason(request);
    if (!accept && reason == null) return;

    setState(() => _busyId = request.id);
    try {
      if (accept) {
        await _repository.approve(widget.organizationId, request.id);
      } else {
        await _repository.reject(widget.organizationId, request.id, reason: reason!.isEmpty ? null : reason);
      }
      if (mounted) showDone(context, accept ? 'Demande acceptée' : 'Demande refusée');
      await _refresh();
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  /// Retourne le motif saisi, une chaîne vide si le responsable n'en donne pas, null s'il annule.
  Future<String?> _askReason(JoinRequestSummary request) {
    final controller = TextEditingController();

    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Refuser la demande'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${request.userName ?? 'Ce membre'} sera prévenu du refus.'),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              maxLength: 280,
              decoration: const InputDecoration(labelText: 'Motif (facultatif)', counterText: ''),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.of(context).pop(controller.text.trim()), child: const Text('Refuser')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Demandes d’adhésion')),
      body: FutureBuilder<List<JoinRequestSummary>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.hasError && !snapshot.hasData) return ErrorView(error: snapshot.error!, onRetry: _refresh);
          if (!snapshot.hasData) return const LoadingView();

          final requests = snapshot.requireData;

          if (requests.isEmpty) {
            return const MessageView(
              icon: Icons.inbox_rounded,
              title: 'Aucune demande',
              message: 'Les demandes d’adhésion à vos tontines publiques et à l’organisation arrivent ici.',
            );
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              itemCount: requests.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final request = requests[index];
                final busy = _busyId == request.id;

                return Panel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(request.userName ?? 'Membre', style: theme.textTheme.titleSmall),
                      const SizedBox(height: 2),
                      Text(
                        request.tontineName == null
                            ? 'Veut rejoindre l’organisation'
                            : 'Veut rejoindre ${request.tontineName}',
                        style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.muted),
                      ),
                      if (request.message != null) ...[
                        const SizedBox(height: 8),
                        Text('« ${request.message} »', style: theme.textTheme.bodyLarge),
                      ],
                      if (request.createdAt != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Demandé le ${dateAndTime(request.createdAt!.toLocal())}',
                          style: theme.textTheme.bodySmall?.copyWith(color: AppColors.muted),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        children: [
                          FilledButton(
                            onPressed: busy ? null : () => _decide(request, accept: true),
                            style: CompactButtons.filled,
                            child: busy ? const ButtonSpinner() : const Text('Accepter'),
                          ),
                          OutlinedButton(
                            onPressed: busy ? null : () => _decide(request, accept: false),
                            style: CompactButtons.outlined,
                            child: const Text('Refuser'),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
