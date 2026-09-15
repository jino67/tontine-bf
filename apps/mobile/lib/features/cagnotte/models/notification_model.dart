class Notification {
  final String id;
  final NotificationType type;
  final String titre;
  final String message;
  final DateTime date;
  final bool lu;
  final Map<String, dynamic> data;

  Notification({
    required this.id,
    required this.type,
    required this.titre,
    required this.message,
    required this.date,
    this.lu = false,
    this.data = const {},
  });

  factory Notification.fromJson(Map<String, dynamic> json) {
    return Notification(
      id: json['id'] ?? '',
      type: _parseNotificationType(json['type']),
      titre: json['titre'] ?? '',
      message: json['message'] ?? '',
      date: DateTime.parse(json['date']),
      lu: (json['lu'] ?? false) == true,
      data: json['data'] ?? {},
    );
  }

  static NotificationType _parseNotificationType(String type) {
    switch (type) {
      case 'cagnotte_urgence': return NotificationType.cagnotteUrgence;
      case 'gain': return NotificationType.gain;
      case 'nouveau_message': return NotificationType.nouveauMessage;
      case 'resultat_tirage': return NotificationType.resultatTirage;
      default: return NotificationType.general;
    }
  }
}

enum NotificationType {
  cagnotteUrgence,
  gain,
  nouveauMessage,
  resultatTirage,
  general,
}