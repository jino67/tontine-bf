enum TypeTontine {
  tirageAuSort,
  tourDeRole,
  cagnotteSolidaire,
  epargnePersonnelle,
  epargneGroupe,
}

enum Frequency {
  quotidien,
  hebdomadaire,
  mensuel,
}

enum TontineStatus {
  pending,
  active,
  completed,
  cancelled,
}

class Tontine {
  final String id;
  final String nom;
  final TypeTontine type;
  final double montantCotisation;
  final Frequency frequence;
  final int duree;
  final int maxParticipants;
  final String createurId;
  final DateTime dateCreation;
  final TontineStatus status;
  final List<String> participants;
  final List<String> gagnants;
  final String? codeInvitation;
  final bool isSystemDefault;
  final String? objectif;
  final double montantActuel;

  Tontine({
    required this.id,
    required this.nom,
    required this.type,
    required this.montantCotisation,
    required this.frequence,
    required this.duree,
    this.maxParticipants = 1,
    required this.createurId,
    required this.dateCreation,
    this.status = TontineStatus.pending,
    required this.participants,
    this.gagnants = const [],
    this.codeInvitation,
    this.isSystemDefault = false,
    this.objectif,
    this.montantActuel = 0,
  });

  factory Tontine.fromJson(Map<String, dynamic> json) {
    return Tontine(
      id: json['id']?.toString() ?? '',
      nom: json['nom']?.toString() ?? 'Tontine sans nom',
      type: _parseTypeTontine(json['type']?.toString() ?? 'tirage_au_sort'),
      montantCotisation: (json['montant_cotisation'] as num?)?.toDouble() ?? 0.0,
      frequence: _parseFrequency(json['frequence']?.toString() ?? 'mensuel'),
      duree: (json['duree'] as num?)?.toInt() ?? 1,
      maxParticipants: (json['max_participants'] as num?)?.toInt() ?? 1,
      createurId: json['createur_id']?.toString() ?? '',
      dateCreation: DateTime.tryParse(json['date_creation']?.toString() ?? '') ?? DateTime.now(),
      status: _parseStatus(json['status']?.toString() ?? 'pending'),
      participants: List<String>.from(json['participants'] is String
          ? (json['participants'] as String).split(',')
          : (json['participants'] as List?)?.cast<String>() ?? []),
      gagnants: List<String>.from(json['gagnants'] is String
          ? (json['gagnants'] as String).split(',')
          : (json['gagnants'] as List?)?.cast<String>() ?? []),
      codeInvitation: json['code_invitation']?.toString(),
      isSystemDefault: (json['is_system_default'] as num?)?.toInt() == 1,
      objectif: json['objectif']?.toString(),
      montantActuel: (json['montant_actuel'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nom': nom,
      'type': _typeToString(type),
      'montant_cotisation': montantCotisation,
      'frequence': _frequencyToString(frequence),
      'duree': duree,
      'max_participants': maxParticipants,
      'createur_id': createurId,
      'date_creation': dateCreation.toIso8601String(),
      'status': _statusToString(status),
      'participants': participants.join(','),
      'gagnants': gagnants.join(','),
      'code_invitation': codeInvitation,
      'is_system_default': isSystemDefault ? 1 : 0,
      'objectif': objectif,
      'montant_actuel': montantActuel,
    };
  }

  static TypeTontine _parseTypeTontine(String type) {
    switch (type) {
      case 'tirage_au_sort': return TypeTontine.tirageAuSort;
      case 'tour_de_role': return TypeTontine.tourDeRole;
      case 'cagnotte_solidaire': return TypeTontine.cagnotteSolidaire;
      case 'epargne_personnelle': return TypeTontine.epargnePersonnelle;
      case 'epargne_groupe': return TypeTontine.epargneGroupe;
      default: return TypeTontine.tirageAuSort;
    }
  }

  static Frequency _parseFrequency(String freq) {
    switch (freq) {
      case 'quotidien': return Frequency.quotidien;
      case 'hebdomadaire': return Frequency.hebdomadaire;
      case 'mensuel': return Frequency.mensuel;
      default: return Frequency.mensuel;
    }
  }

  static TontineStatus _parseStatus(String status) {
    switch (status) {
      case 'pending': return TontineStatus.pending;
      case 'active': return TontineStatus.active;
      case 'completed': return TontineStatus.completed;
      case 'cancelled': return TontineStatus.cancelled;
      default: return TontineStatus.pending;
    }
  }

  static String _typeToString(TypeTontine type) {
    switch (type) {
      case TypeTontine.tirageAuSort: return 'tirage_au_sort';
      case TypeTontine.tourDeRole: return 'tour_de_role';
      case TypeTontine.cagnotteSolidaire: return 'cagnotte_solidaire';
      case TypeTontine.epargnePersonnelle: return 'epargne_personnelle';
      case TypeTontine.epargneGroupe: return 'epargne_groupe';
    }
  }

  static String _frequencyToString(Frequency freq) {
    switch (freq) {
      case Frequency.quotidien: return 'quotidien';
      case Frequency.hebdomadaire: return 'hebdomadaire';
      case Frequency.mensuel: return 'mensuel';
    }
  }

  static String _statusToString(TontineStatus status) {
    switch (status) {
      case TontineStatus.pending: return 'pending';
      case TontineStatus.active: return 'active';
      case TontineStatus.completed: return 'completed';
      case TontineStatus.cancelled: return 'cancelled';
    }
  }

  String get typeString {
    switch (type) {
      case TypeTontine.tirageAuSort: return 'Tirage au Sort';
      case TypeTontine.tourDeRole: return 'Tour de Rôle';
      case TypeTontine.cagnotteSolidaire: return 'Cagnotte Solidaire';
      case TypeTontine.epargnePersonnelle: return 'Épargne Personnelle';
      case TypeTontine.epargneGroupe: return 'Épargne de Groupe';
    }
  }

  String get frequencyString {
    switch (frequence) {
      case Frequency.quotidien: return 'Quotidien';
      case Frequency.hebdomadaire: return 'Hebdomadaire';
      case Frequency.mensuel: return 'Mensuel';
    }
  }

  String get statusString {
    switch (status) {
      case TontineStatus.pending: return 'En attente';
      case TontineStatus.active: return 'Active';
      case TontineStatus.completed: return 'Terminée';
      case TontineStatus.cancelled: return 'Annulée';
    }
  }

  bool get isActive => status == TontineStatus.active;
  bool get isPending => status == TontineStatus.pending;
  bool get isCompleted => status == TontineStatus.completed;
  bool get isCancelled => status == TontineStatus.cancelled;

  String generateInvitationCode() {
    return 'TONTINE-${DateTime.now().millisecondsSinceEpoch}'.substring(0, 8);
  }

  String generateDeepLink() {
    return 'https://tontinebf.page.link/invite?code=$codeInvitation&type=${_typeToString(type)}';
  }

  bool get isFull {
    return participants.length >= maxParticipants;
  }

  double get progress {
    if (type == TypeTontine.epargnePersonnelle || type == TypeTontine.epargneGroupe) {
      return montantActuel / (montantCotisation * duree);
    }
    return participants.length / maxParticipants;
  }

  double get progressPercentage {
    return progress.clamp(0.0, 1.0);
  }
}