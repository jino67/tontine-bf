import '../../core/json.dart';

/// Demande d'adhésion à une organisation ou à une tontine.
class JoinRequestSummary {
  const JoinRequestSummary({
    required this.id,
    required this.status,
    this.message,
    this.decisionReason,
    this.organizationName,
    this.tontineName,
    this.userName,
    this.createdAt,
  });

  factory JoinRequestSummary.fromJson(Map<String, dynamic> json) => JoinRequestSummary(
        id: asInt(json['id']),
        status: '${json['status'] ?? ''}',
        message: asStringOrNull(json['message']),
        decisionReason: asStringOrNull(json['decision_reason']),
        organizationName: asStringOrNull(asMap(json['organization'])['name']),
        tontineName: json['tontine'] is Map<String, dynamic> ? asStringOrNull(asMap(json['tontine'])['name']) : null,
        userName: json['user'] is Map<String, dynamic> ? asStringOrNull(asMap(json['user'])['name']) : null,
        createdAt: asDate(json['created_at']),
      );

  final int id;
  final String status;
  final String? message;
  final String? decisionReason;
  final String? organizationName;
  final String? tontineName;
  final String? userName;
  final DateTime? createdAt;

  bool get isPending => status == 'en_attente';

  String get target => tontineName ?? organizationName ?? 'Organisation';

  String get statusLabel => switch (status) {
        'en_attente' => 'En attente',
        'approuvee' => 'Acceptée',
        'refusee' => 'Refusée',
        _ => 'Retirée',
      };
}

/// Motifs de signalement d'une fiche publique, tels que l'API les attend.
enum ReportReason {
  scam('arnaque', 'Tentative d’arnaque'),
  misleading('trompeur', 'Contenu trompeur'),
  amounts('montants_irrealistes', 'Montants irréalistes'),
  impersonation('usurpation', 'Usurpation d’identité'),
  other('autre', 'Autre');

  const ReportReason(this.apiValue, this.label);

  final String apiValue;
  final String label;
}
