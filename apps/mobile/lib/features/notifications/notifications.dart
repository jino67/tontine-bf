import '../../core/api/api_client.dart';
import '../../core/json.dart';

/// Message reçu par un membre.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.label,
    required this.title,
    required this.body,
    required this.channel,
    required this.read,
    this.relatedKind,
    this.relatedId,
    this.organizationId,
    this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    final related = asMap(json['related']);

    return AppNotification(
      id: asInt(json['id']),
      type: '${json['type']}',
      label: '${json['label']}',
      title: '${json['title']}',
      body: '${json['body']}',
      channel: '${json['channel']}',
      read: json['read'] == true,
      relatedKind: asStringOrNull(related['kind']),
      relatedId: asIntOrNull(related['id']),
      organizationId: asIntOrNull(json['organization_id']),
      createdAt: asDate(json['created_at']),
    );
  }

  final int id;
  final String type;
  final String label;
  final String title;
  final String body;
  final String channel;
  final bool read;

  /// « tontine », « cagnotte » : de quoi ouvrir la bonne fiche.
  final String? relatedKind;
  final int? relatedId;
  final int? organizationId;
  final DateTime? createdAt;

  bool get isReminder => type.startsWith('rappel') || type == 'recapitulatif_tresorier';
}

/// Ce qu'un membre accepte de recevoir.
class NotificationSettings {
  const NotificationSettings({
    required this.reminders,
    required this.mail,
    required this.push,
    required this.whatsapp,
    required this.sms,
    required this.muted,
  });

  factory NotificationSettings.fromJson(Map<String, dynamic> json) => NotificationSettings(
        reminders: json['reminders'] != false,
        mail: json['mail'] != false,
        push: json['push'] != false,
        whatsapp: json['whatsapp'] != false,
        sms: json['sms'] == true,
        muted: asStringList(json['muted']),
      );

  final bool reminders;
  final bool mail;
  final bool push;
  final bool whatsapp;
  final bool sms;

  /// Objets dont les relances sont coupées, sous la forme « tontine:12 ».
  final List<String> muted;

  bool mutes(String kind, int id) => muted.contains('$kind:$id');
}

class NotificationsRepository {
  NotificationsRepository(this._api);

  final ApiClient _api;

  Future<({List<AppNotification> items, int unread})> list() async {
    final body = asMap(await _api.get('/notifications'));

    return (
      items: asMapList(body['data']).map(AppNotification.fromJson).toList(),
      unread: asInt(asMap(body['meta'])['unread']),
    );
  }

  Future<void> markRead(int id) => _api.post('/notifications/$id/read');

  Future<void> markAllRead() => _api.post('/notifications/read-all');

  Future<NotificationSettings> settings() async =>
      NotificationSettings.fromJson(asMap(unwrap(await _api.get('/notifications/settings'))));

  Future<NotificationSettings> updateSettings(Map<String, dynamic> changes) async =>
      NotificationSettings.fromJson(asMap(unwrap(await _api.put('/notifications/settings', changes))));
}
