class GroupeDiscussion {
  final int id;
  final int cagnotteId;
  final String nom;
  final DateTime createdAt;
  final String cagnotteNom;
  final String cagnotteType;
  final String cagnotteStatus;
  final DateTime cagnotteDateFin;
  final int messagesCount;
  final String? dernierMessage;
  final DateTime? dernierMessageDate;
  final bool estGagnant;

  GroupeDiscussion({
    required this.id,
    required this.cagnotteId,
    required this.nom,
    required this.createdAt,
    required this.cagnotteNom,
    required this.cagnotteType,
    required this.cagnotteStatus,
    required this.cagnotteDateFin,
    this.messagesCount = 0,
    this.dernierMessage,
    this.dernierMessageDate,
    this.estGagnant = false,
  });

  factory GroupeDiscussion.fromJson(Map<String, dynamic> json) {
    return GroupeDiscussion(
      id: json['id'] ?? 0,
      cagnotteId: json['cagnotte_id'] ?? 0,
      nom: json['nom'] ?? '',
      createdAt: DateTime.parse(json['created_at']),
      cagnotteNom: json['cagnotte_nom'] ?? '',
      cagnotteType: json['cagnotte_type'] ?? '',
      cagnotteStatus: json['cagnotte_status'] ?? '',
      cagnotteDateFin: DateTime.parse(json['date_fin']),
      messagesCount: json['messages_count'] ?? 0,
      dernierMessage: json['dernier_message'],
      dernierMessageDate: json['dernier_message_date'] != null
          ? DateTime.parse(json['dernier_message_date'])
          : null,
      estGagnant: (json['est_gagnant'] ?? 0) == 1,
    );
  }
}

class MessageGroupe {
  final int id;
  final int groupeId;
  final int userId;
  final String message;
  final MessageType type;
  final DateTime createdAt;
  final String userName;
  final String userPhone;
  final bool estMessageVictoire;

  MessageGroupe({
    required this.id,
    required this.groupeId,
    required this.userId,
    required this.message,
    required this.type,
    required this.createdAt,
    required this.userName,
    required this.userPhone,
    this.estMessageVictoire = false,
  });

  factory MessageGroupe.fromJson(Map<String, dynamic> json) {
    return MessageGroupe(
      id: json['id'] ?? 0,
      groupeId: json['groupe_id'] ?? 0,
      userId: json['user_id'] ?? 0,
      message: json['message'] ?? '',
      type: _parseMessageType(json['type']),
      createdAt: DateTime.parse(json['created_at']),
      userName: json['full_name'] ?? '',
      userPhone: json['phone_number'] ?? '',
      estMessageVictoire: (json['est_message_victoire'] ?? 0) == 1,
    );
  }

  static MessageType _parseMessageType(String type) {
    switch (type) {
      case 'victoire': return MessageType.victoire;
      case 'normal': return MessageType.normal;
      default: return MessageType.normal;
    }
  }
}

enum MessageType { normal, victoire }