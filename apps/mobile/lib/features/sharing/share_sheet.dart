import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/theme.dart';
import '../../core/widgets/brand.dart';
import '../../core/widgets/ui.dart';
import 'sharing.dart';

/// Partage d'une tontine, d'une cagnotte ou d'une organisation : lien, QR code, WhatsApp.
///
/// [subject] complète la phrase « Rejoignez … sur Tontine BF ».
/// [onVisibilityChanged] est appelé quand un responsable change le réglage, et retourne la nouvelle adresse.
Future<void> showShareSheet(
  BuildContext context, {
  required String title,
  required String subject,
  required ShareVisibility visibility,
  required String? shareUrl,
  required bool canManage,
  required Future<String?> Function(ShareVisibility visibility) onVisibilityChanged,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _ShareSheet(
      title: title,
      subject: subject,
      visibility: visibility,
      shareUrl: shareUrl,
      canManage: canManage,
      onVisibilityChanged: onVisibilityChanged,
    ),
  );
}

class _ShareSheet extends StatefulWidget {
  const _ShareSheet({
    required this.title,
    required this.subject,
    required this.visibility,
    required this.shareUrl,
    required this.canManage,
    required this.onVisibilityChanged,
  });

  final String title;
  final String subject;
  final ShareVisibility visibility;
  final String? shareUrl;
  final bool canManage;
  final Future<String?> Function(ShareVisibility visibility) onVisibilityChanged;

  @override
  State<_ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends State<_ShareSheet> {
  late ShareVisibility _visibility = widget.visibility;
  late String? _url = widget.shareUrl;
  bool _saving = false;
  bool _copied = false;
  String? _error;

  String get _message => 'Rejoignez ${widget.subject} sur Tontine BF : $_url';

  Future<void> _change(ShareVisibility visibility) async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final url = await widget.onVisibilityChanged(visibility);
      if (!mounted) return;
      setState(() {
        _visibility = visibility;
        _url = url;
        _copied = false;
        _saving = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = errorText(error);
      });
    }
  }

  Future<void> _sendToWhatsApp() async {
    final uri = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(_message)}');
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened && mounted) setState(() => _error = 'WhatsApp ne s’est pas ouvert. Copiez le lien et envoyez-le autrement.');
    } catch (_) {
      if (mounted) setState(() => _error = 'WhatsApp ne s’est pas ouvert. Copiez le lien et envoyez-le autrement.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final url = _url;

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 0, 24, 24 + MediaQuery.viewPaddingOf(context).bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Partager', style: theme.textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(widget.title, style: theme.textTheme.bodyLarge?.copyWith(color: AppColors.muted)),
            const SizedBox(height: 20),
            if (url == null) ...[
              Panel(
                child: Text(
                  widget.canManage
                      ? 'Cette page est privée : seuls les membres la voient. Créez un lien pour pouvoir la partager.'
                      : 'Cette page est privée. Demandez à un responsable de créer un lien de partage.',
                  style: theme.textTheme.bodyLarge,
                ),
              ),
              if (widget.canManage) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _saving ? null : () => _change(ShareVisibility.link),
                    child: _saving ? const ButtonSpinner() : const Text('Créer le lien'),
                  ),
                ),
              ],
            ] else ...[
              Center(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.line),
                  ),
                  child: QrImageView(data: url, size: 168, padding: EdgeInsets.zero),
                ),
              ),
              const SizedBox(height: 16),
              SelectableText(url, style: AppType.sans(size: 15, color: AppColors.muted)),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _sendToWhatsApp,
                  icon: const Icon(Icons.send_rounded),
                  label: const Text('Envoyer par WhatsApp'),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: _message));
                    if (mounted) setState(() => _copied = true);
                  },
                  icon: Icon(_copied ? Icons.check_rounded : Icons.copy_rounded),
                  label: Text(_copied ? 'Message copié' : 'Copier le message'),
                ),
              ),
            ],
            if (widget.canManage) ...[
              const SizedBox(height: 22),
              Text('Qui peut voir cette page', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final visibility in ShareVisibility.values)
                    ChoiceChip(
                      label: Text(visibility.label),
                      selected: _visibility == visibility,
                      showCheckmark: false,
                      onSelected: _saving ? null : (_) => _change(visibility),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(_visibility.description, style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.muted)),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: AppType.sans(color: AppColors.chili)),
            ],
          ],
        ),
      ),
    );
  }
}
