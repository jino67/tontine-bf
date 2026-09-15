import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/theme.dart';
import '../../core/format.dart';
import '../../core/session/session_scope.dart';
import '../../core/widgets/ui.dart';
import 'organization.dart';

/// Crée un code d'invitation et propose de le partager.
Future<void> showInviteSheet(BuildContext context, {required Organization organization, int? tontineId, String? tontineName}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _InviteSheet(organization: organization, tontineId: tontineId, tontineName: tontineName),
  );
}

class _InviteSheet extends StatefulWidget {
  const _InviteSheet({required this.organization, this.tontineId, this.tontineName});

  final Organization organization;
  final int? tontineId;
  final String? tontineName;

  @override
  State<_InviteSheet> createState() => _InviteSheetState();
}

class _InviteSheetState extends State<_InviteSheet> {
  late Future<Invitation> _future;
  bool _copied = false;
  bool _shareFailed = false;

  @override
  void initState() {
    super.initState();
    _future = _create();
  }

  Future<Invitation> _create() =>
      SessionScope.read(context).organizations.createInvitation(widget.organization.id, tontineId: widget.tontineId);

  String _message(Invitation invitation) {
    final target = widget.tontineName == null ? widget.organization.name : '${widget.organization.name}, tontine ${widget.tontineName}';
    return 'Rejoignez $target sur Tontine BF. Ouvrez l’application, touchez « Rejoindre avec un code » '
        'et saisissez : ${invitation.code}';
  }

  Future<void> _share(Invitation invitation) async {
    final uri = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(_message(invitation))}');
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened && mounted) setState(() => _shareFailed = true);
    } catch (_) {
      if (mounted) setState(() => _shareFailed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 0, 24, 24 + MediaQuery.viewPaddingOf(context).bottom),
      child: FutureBuilder<Invitation>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Code non créé', style: theme.textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(errorText(snapshot.error!), style: theme.textTheme.bodyLarge),
                const SizedBox(height: 16),
                OutlinedButton(onPressed: () => setState(() => _future = _create()), child: const Text('Réessayer')),
              ],
            );
          }
          if (!snapshot.hasData) return const SizedBox(height: 200, child: LoadingView());

          final invitation = snapshot.requireData;
          final code = invitation.code;
          final grouped = code.length == 8 ? '${code.substring(0, 4)} ${code.substring(4)}' : code;

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Inviter des membres', style: theme.textTheme.titleLarge),
              const SizedBox(height: 6),
              Text(
                widget.tontineName == null
                    ? 'Ce code permet de rejoindre ${widget.organization.name}.'
                    : 'Ce code permet de rejoindre ${widget.organization.name} et la tontine ${widget.tontineName}.',
                style: theme.textTheme.bodyLarge?.copyWith(color: AppColors.muted),
              ),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 22),
                decoration: BoxDecoration(
                  color: AppColors.cotton,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.line),
                ),
                child: SelectableText(
                  grouped,
                  textAlign: TextAlign.center,
                  style: AppType.code(32, color: AppColors.leafDeep),
                ),
              ),
              if (invitation.expiresAt != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Valable jusqu’au ${shortDate(invitation.expiresAt!.toLocal())}.',
                  style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.muted),
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => _share(invitation),
                  icon: const Icon(Icons.send_rounded),
                  label: const Text('Envoyer par WhatsApp'),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: _message(invitation)));
                    if (mounted) setState(() => _copied = true);
                  },
                  icon: Icon(_copied ? Icons.check_rounded : Icons.copy_rounded),
                  label: Text(_copied ? 'Message copié' : 'Copier le message'),
                ),
              ),
              if (_shareFailed) ...[
                const SizedBox(height: 12),
                Text(
                  'WhatsApp ne s’est pas ouvert. Copiez le message et envoyez-le depuis l’application de votre choix.',
                  style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.chili),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
