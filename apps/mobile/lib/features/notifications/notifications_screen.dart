import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/format.dart';
import '../../core/session/session_scope.dart';
import '../../core/widgets/ui.dart';
import 'notifications.dart';

/// Messages reçus, et ce que le membre accepte de recevoir.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late NotificationsRepository _repository;
  late Future<({List<AppNotification> items, int unread})> _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _repository = NotificationsRepository(SessionScope.read(context).api);
    _future = _repository.list();
  }

  Future<void> _refresh() async {
    final future = _repository.list();
    setState(() => _future = future);
    try {
      await future;
    } catch (_) {
      // L'erreur est affichée à l'écran.
    }
  }

  Future<void> _markAll() async {
    try {
      await _repository.markAllRead();
      await _refresh();
    } catch (error) {
      if (mounted) showError(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          IconButton(
            tooltip: 'Réglages',
            icon: const Icon(Icons.tune_rounded),
            onPressed: () => Navigator.of(context)
                .push(MaterialPageRoute<void>(builder: (_) => const NotificationSettingsScreen())),
          ),
        ],
      ),
      body: FutureBuilder<({List<AppNotification> items, int unread})>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.hasError && !snapshot.hasData) return ErrorView(error: snapshot.error!, onRetry: _refresh);
          if (!snapshot.hasData) return const LoadingView();

          final data = snapshot.requireData;

          if (data.items.isEmpty) {
            return const MessageView(
              icon: Icons.notifications_none_rounded,
              title: 'Aucun message',
              message: 'Les rappels de cotisation, les tirages et l’argent reçu apparaîtront ici.',
            );
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              children: [
                if (data.unread > 0)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        Expanded(child: Text(countLabel(data.unread, 'message non lu', 'messages non lus'))),
                        TextButton(onPressed: _markAll, child: const Text('Tout marquer lu')),
                      ],
                    ),
                  ),
                for (final item in data.items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _NotificationTile(
                      notification: item,
                      onRead: () async {
                        if (item.read) return;
                        await _repository.markRead(item.id);
                        await _refresh();
                      },
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification, required this.onRead});

  final AppNotification notification;
  final VoidCallback onRead;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onRead,
      borderRadius: BorderRadius.circular(16),
      child: Panel(
        color: notification.read ? Colors.white : AppColors.leafSoft,
        borderColor: notification.read ? AppColors.line : AppColors.leafSoft,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(notification.title, style: AppType.sans(bold: true))),
                if (!notification.read)
                  Container(
                    width: 9,
                    height: 9,
                    decoration: const BoxDecoration(color: AppColors.leaf, shape: BoxShape.circle),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(notification.body, style: theme.textTheme.bodyMedium),
            if (notification.createdAt != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  dateAndTime(notification.createdAt!),
                  style: theme.textTheme.bodySmall?.copyWith(color: AppColors.muted),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Ce que le membre accepte de recevoir, et par quel canal.
class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  late NotificationsRepository _repository;
  NotificationSettings? _settings;
  Object? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _repository = NotificationsRepository(SessionScope.read(context).api);
    _load();
  }

  Future<void> _load() async {
    try {
      final settings = await _repository.settings();
      if (mounted) setState(() => _settings = settings);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  /// Rétablit les relances d'une tontine que le membre avait coupées.
  Future<void> _unmute(String key) async {
    final remaining = [...?_settings?.muted]..remove(key);

    try {
      final updated = await _repository.updateSettings({'muted': remaining});
      if (!mounted) return;
      setState(() => _settings = updated);
    } catch (error) {
      if (!mounted) return;
      showError(context, error);
    }
  }

  Future<void> _set(String key, bool value) async {
    try {
      final settings = await _repository.updateSettings({key: value});
      if (mounted) setState(() => _settings = settings);
    } catch (error) {
      if (mounted) showError(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = _settings;

    return Scaffold(
      appBar: AppBar(title: const Text('Réglages des notifications')),
      body: _error != null
          ? ErrorView(error: _error!, onRetry: _load)
          : settings == null
              ? const LoadingView()
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                  children: [
                    SwitchListTile(
                      value: settings.reminders,
                      onChanged: (value) => _set('reminders', value),
                      title: const Text('Rappels de cotisation'),
                      subtitle: const Text(
                        'Trois jours avant l’échéance, le jour même, puis en cas de retard.',
                      ),
                    ),
                    const Divider(),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Text('Par où', style: theme.textTheme.titleMedium),
                    ),
                    SwitchListTile(
                      value: settings.push,
                      onChanged: (value) => _set('push', value),
                      title: const Text('Notification sur le téléphone'),
                    ),
                    SwitchListTile(
                      value: settings.whatsapp,
                      onChanged: (value) => _set('whatsapp', value),
                      title: const Text('WhatsApp'),
                      subtitle: const Text('Pour les relances de paiement et l’argent reçu.'),
                    ),
                    SwitchListTile(
                      value: settings.mail,
                      onChanged: (value) => _set('mail', value),
                      title: const Text('E-mail'),
                      subtitle: const Text('Récapitulatifs et messages importants.'),
                    ),
                    SwitchListTile(
                      value: settings.sms,
                      onChanged: (value) => _set('sms', value),
                      title: const Text('SMS'),
                      subtitle: const Text('Le plus cher : réservé aux retards importants.'),
                    ),
                    const SizedBox(height: 12),
                    Panel(
                      child: Text(
                        'Quoi qu’il arrive, chaque message reste visible dans cette rubrique. '
                        'Vous pouvez aussi couper les relances d’une tontine précise depuis sa fiche, '
                        'sans couper les autres.',
                        style: theme.textTheme.bodySmall?.copyWith(color: AppColors.muted),
                      ),
                    ),
                    if (settings.muted.isNotEmpty) ...[
                      const SectionTitle('Relances coupées'),
                      for (final key in settings.muted)
                        ListTile(
                          leading: const Icon(Icons.notifications_off_outlined, color: AppColors.muted),
                          title: Text(key.replaceFirst(':', ' n° ')),
                          trailing: TextButton(
                            onPressed: () => _unmute(key),
                            child: const Text('Rétablir'),
                          ),
                        ),
                    ],
                  ],
                ),
    );
  }
}
