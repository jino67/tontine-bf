import 'cagnotte_model.dart';

class Participation {
  final int id;
  final int userId;
  final int cagnotteId;
  final double montant;
  final int tickets;
  final DateTime dateParticipation;
  final String cagnotteNom;
  final CagnotteType cagnotteType;
  final DateTime cagnotteDateFin;
  final CagnotteStatus cagnotteStatus;
  final double cagnotteMontantTotal;
  final bool aGagne;

  Participation({
    required this.id,
    required this.userId,
    required this.cagnotteId,
    required this.montant,
    required this.tickets,
    required this.dateParticipation,
    required this.cagnotteNom,
    required this.cagnotteType,
    required this.cagnotteDateFin,
    required this.cagnotteStatus,
    required this.cagnotteMontantTotal,
    this.aGagne = false,
  });

  factory Participation.fromJson(Map<String, dynamic> json) {
    return Participation(
      id: json['id'] ?? 0,
      userId: json['user_id'] ?? 0,
      cagnotteId: json['cagnotte_id'] ?? 0,
      montant: (json['montant'] ?? 0).toDouble(),
      tickets: json['tickets'] ?? 0,
      dateParticipation: DateTime.parse(json['date_participation']),
      cagnotteNom: json['nom'] ?? '',
      cagnotteType: _parseCagnotteType(json['type']),
      cagnotteDateFin: DateTime.parse(json['date_fin']),
      cagnotteStatus: _parseCagnotteStatus(json['status']),
      cagnotteMontantTotal: (json['montant_total'] ?? 0).toDouble(),
      aGagne: (json['a_gagne'] ?? 0) > 0,
    );
  }

  static CagnotteType _parseCagnotteType(String type) {
    switch (type) {
      case 'flash_24h': return CagnotteType.flash24h;
      case 'hebdo_7j': return CagnotteType.hebdo7j;
      case 'mensuelle_30j': return CagnotteType.mensuelle30j;
      default: return CagnotteType.flash24h;
    }
  }

  static CagnotteStatus _parseCagnotteStatus(String status) {
    switch (status) {
      case 'active': return CagnotteStatus.active;
      case 'terminee': return CagnotteStatus.terminee;
      case 'en_cours': return CagnotteStatus.enCours;
      default: return CagnotteStatus.active;
    }
  }
}