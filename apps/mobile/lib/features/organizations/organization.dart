import '../../core/json.dart';

enum Role {
  owner('owner', 'Propriétaire', 'Gère l’organisation et attribue les rôles.'),
  admin('admin', 'Responsable', 'Crée les tontines et invite les membres.'),
  treasurer('tresorier', 'Trésorier', 'Enregistre les paiements et voit toutes les tontines.'),
  member('membre', 'Membre', 'Cotise et confirme ses paiements.');

  const Role(this.apiValue, this.label, this.description);

  final String apiValue;
  final String label;
  final String description;

  bool get canManage => this == owner || this == admin;
  bool get canRecordPayments => canManage || this == treasurer;

  static Role fromApi(Object? value) => values.firstWhere((role) => role.apiValue == value, orElse: () => member);
}

class Organization {
  const Organization({required this.id, required this.name, required this.role, this.plan});

  factory Organization.fromJson(Map<String, dynamic> json) => Organization(
        id: asInt(json['id']),
        name: '${json['name'] ?? ''}',
        role: Role.fromApi(json['role']),
        plan: asStringOrNull(json['plan']),
      );

  final int id;
  final String name;
  final Role role;
  final String? plan;
}

/// Personne telle que la voient les autres membres (numéro éventuellement masqué).
class MemberUser {
  const MemberUser({required this.id, required this.phone, this.name});

  factory MemberUser.fromJson(Map<String, dynamic> json) => MemberUser(
        id: asInt(json['id']),
        phone: '${json['phone'] ?? ''}',
        name: asStringOrNull(json['name']),
      );

  final int id;
  final String phone;
  final String? name;

  String get displayName => (name ?? '').trim().isEmpty ? 'Membre sans nom' : name!.trim();
}

class Membership {
  const Membership({required this.id, required this.role, required this.user});

  factory Membership.fromJson(Map<String, dynamic> json) => Membership(
        id: asInt(json['id']),
        role: Role.fromApi(json['role']),
        user: MemberUser.fromJson(asMap(json['user'])),
      );

  final int id;
  final Role role;
  final MemberUser user;
}

class Invitation {
  const Invitation({required this.code, this.tontineId, this.maxUses, this.expiresAt});

  factory Invitation.fromJson(Map<String, dynamic> json) => Invitation(
        code: '${json['code'] ?? ''}',
        tontineId: asIntOrNull(json['tontine_id']),
        maxUses: asIntOrNull(json['max_uses']),
        expiresAt: asDate(json['expires_at']),
      );

  final String code;
  final int? tontineId;
  final int? maxUses;
  final DateTime? expiresAt;
}

class JoinResult {
  const JoinResult({required this.organization, this.tontineName});

  final Organization organization;
  final String? tontineName;
}
