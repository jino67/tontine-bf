import 'dart:convert';

class Cagnotte {
  final int id;
  final String nom;
  final CagnotteType type;
  final double montantTotal;
  final double montantMin;
  final List<double> montantsAutorises;
  final bool accepteMontantsLibres;
  final int nombreGagnants;
  final DateTime dateDebut;
  final DateTime dateFin;
  final CagnotteStatus status;
  final int participantsCount;
  final double totalCollecte;
  final bool dejaParticipe;
  final int tempsRestant;
  final String tempsRestantFormate;
  final Map<String, double> gainsPotentiels;
  final int? groupeId;

  Cagnotte({
    required this.id,
    required this.nom,
    required this.type,
    required this.montantTotal,
    required this.montantMin,
    required this.montantsAutorises,
    required this.accepteMontantsLibres,
    required this.nombreGagnants,
    required this.dateDebut,
    required this.dateFin,
    required this.status,
    this.participantsCount = 0,
    this.totalCollecte = 0,
    this.dejaParticipe = false,
    this.tempsRestant = 0,
    this.tempsRestantFormate = '',
    this.gainsPotentiels = const {},
    this.groupeId,
  });

  factory Cagnotte.fromJson(Map<String, dynamic> json) {
    return Cagnotte(
      id: json['id'] ?? 0,
      nom: json['nom'] ?? '',
      type: _parseCagnotteType(json['type']),
      montantTotal: (json['montant_total'] ?? 0).toDouble(),
      montantMin: (json['montant_min'] ?? 250).toDouble(),
      montantsAutorises: _parseMontantsAutorises(json['montants_autorises']),
      accepteMontantsLibres: (json['accepte_montants_libres'] ?? 0) == 1,
      nombreGagnants: json['nombre_gagnants'] ?? 10,
      dateDebut: DateTime.parse(json['date_debut']),
      dateFin: DateTime.parse(json['date_fin']),
      status: _parseCagnotteStatus(json['status']),
      participantsCount: json['participants_count'] ?? 0,
      totalCollecte: (json['total_collecte'] ?? 0).toDouble(),
      dejaParticipe: (json['deja_participe'] ?? 0) == 1,
      tempsRestant: json['temps_restant'] ?? 0,
      tempsRestantFormate: json['temps_restant_formate'] ?? '',
      gainsPotentiels: _parseGainsPotentiels(json['gains_potentiels']),
      groupeId: json['groupe_id'],
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

  static List<double> _parseMontantsAutorises(dynamic data) {
    if (data is String) {
      try {
        List<dynamic> list = json.decode(data);
        return list.map((e) => (e as num).toDouble()).toList();
      } catch (e) {
        return [250.0, 500.0, 1000.0, 2000.0, 5000.0, 10000.0];
      }
    } else if (data is List) {
      return data.map((e) => (e as num).toDouble()).toList();
    }
    return [250.0, 500.0, 1000.0, 2000.0, 5000.0, 10000.0];
  }

  static Map<String, double> _parseGainsPotentiels(dynamic data) {
    if (data is Map) {
      return data.map((key, value) => MapEntry(key.toString(), (value as num).toDouble()));
    }
    return {};
  }

  String get typeString {
    switch (type) {
      case CagnotteType.flash24h: return 'Flash 24h';
      case CagnotteType.hebdo7j: return 'Hebdo 7j';
      case CagnotteType.mensuelle30j: return 'Mensuelle 30j';
    }
  }

  String get statusString {
    switch (status) {
      case CagnotteStatus.active: return 'Active';
      case CagnotteStatus.terminee: return 'Terminée';
      case CagnotteStatus.enCours: return 'En cours';
    }
  }

  bool get estTerminee => status == CagnotteStatus.terminee;
  bool get estActive => status == CagnotteStatus.active;
}

enum CagnotteType { flash24h, hebdo7j, mensuelle30j }
enum CagnotteStatus { active, terminee, enCours }