class Gagnant {
  final int id;
  final int cagnotteId;
  final int userId;
  final int rang;
  final double gain;
  final ModeSelection modeSelection;
  final String? messageVictoire;
  final DateTime dateGain;
  final String userName;
  final String userPhone;

  Gagnant({
    required this.id,
    required this.cagnotteId,
    required this.userId,
    required this.rang,
    required this.gain,
    required this.modeSelection,
    this.messageVictoire,
    required this.dateGain,
    required this.userName,
    required this.userPhone,
  });

  factory Gagnant.fromJson(Map<String, dynamic> json) {
    return Gagnant(
      id: json['id'] ?? 0,
      cagnotteId: json['cagnotte_id'] ?? 0,
      userId: json['user_id'] ?? 0,
      rang: json['rang'] ?? 0,
      gain: (json['gain'] ?? 0).toDouble(),
      modeSelection: _parseModeSelection(json['mode_selection']),
      messageVictoire: json['message_victoire'],
      dateGain: DateTime.parse(json['date_gain']),
      userName: json['user_name'] ?? '',
      userPhone: json['user_phone'] ?? '',
    );
  }

  static ModeSelection _parseModeSelection(String mode) {
    switch (mode) {
      case 'admin': return ModeSelection.admin;
      case 'aleatoire': return ModeSelection.aleatoire;
      default: return ModeSelection.aleatoire;
    }
  }

  String get rangString {
    switch (rang) {
      case 1: return '1er';
      case 2: return '2ème';
      case 3: return '3ème';
      default: return '${rang}ème';
    }
  }
}

enum ModeSelection { aleatoire, admin }