import 'package:flutter/material.dart' show IconData, Icons;

import '../../core/json.dart';
import '../organizations/organization.dart';

enum TontineType {
  rotative('rotative', 'Tour de rôle', Icons.autorenew_rounded),
  drawOrder('tirage_ordre', 'Ordre tiré au sort', Icons.casino_outlined),
  groupSavings('epargne_groupe', 'Épargne de groupe', Icons.groups_2_outlined),
  personalSavings('epargne_perso', 'Épargne personnelle', Icons.savings_outlined);

  const TontineType(this.apiValue, this.label, this.icon);

  final String apiValue;
  final String label;
  final IconData icon;

  /// Chaque part reçoit la cagnotte une fois : le nombre de tours découle des parts.
  bool get hasBeneficiaries => this == rotative || this == drawOrder;

  static TontineType fromApi(Object? value) =>
      values.firstWhere((type) => type.apiValue == value, orElse: () => rotative);
}

enum Frequency {
  daily('quotidien', 'Chaque jour', 'par jour'),
  weekly('hebdomadaire', 'Chaque semaine', 'par semaine'),
  monthly('mensuel', 'Chaque mois', 'par mois');

  const Frequency(this.apiValue, this.label, this.perPeriod);

  final String apiValue;
  final String label;
  final String perPeriod;

  static Frequency fromApi(Object? value) =>
      values.firstWhere((frequency) => frequency.apiValue == value, orElse: () => monthly);
}

enum TontineStatus {
  draft('brouillon', 'Inscriptions ouvertes'),
  active('active', 'En cours'),
  completed('terminee', 'Terminée'),
  cancelled('annulee', 'Annulée');

  const TontineStatus(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static TontineStatus fromApi(Object? value) =>
      values.firstWhere((status) => status.apiValue == value, orElse: () => draft);
}

enum CycleStatus {
  upcoming('a_venir', 'À venir'),
  open('en_cours', 'À encaisser'),
  settled('regle', 'Réglé');

  const CycleStatus(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static CycleStatus fromApi(Object? value) =>
      values.firstWhere((status) => status.apiValue == value, orElse: () => upcoming);
}

enum ContributionStatus {
  pending('en_attente', 'À payer'),
  recorded('enregistree', 'À confirmer'),
  confirmed('confirmee', 'Confirmée');

  const ContributionStatus(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static ContributionStatus fromApi(Object? value) =>
      values.firstWhere((status) => status.apiValue == value, orElse: () => pending);
}

enum PaymentMethod {
  cash('especes', 'Espèces'),
  orangeMoney('orange_money', 'Orange Money'),
  moovMoney('moov_money', 'Moov Money'),
  bankTransfer('virement', 'Virement'),
  other('autre', 'Autre'),
  paydunya('paydunya', 'PayDunya');

  const PaymentMethod(this.apiValue, this.label);

  final String apiValue;
  final String label;

  /// Moyens saisis à la main. Un paiement PayDunya n'est jamais saisi : c'est le prestataire qui le confirme.
  static List<PaymentMethod> get manual => [for (final method in values) if (method != paydunya) method];

  static PaymentMethod? fromApi(Object? value) {
    for (final method in values) {
      if (method.apiValue == value) return method;
    }
    return null;
  }
}

class TontineMember {
  const TontineMember({required this.id, required this.shares, this.position, this.user});

  factory TontineMember.fromJson(Map<String, dynamic> json) => TontineMember(
        id: asInt(json['id']),
        shares: asInt(json['shares']).clamp(1, 99),
        position: asIntOrNull(json['position']),
        user: json['user'] is Map<String, dynamic> ? MemberUser.fromJson(json['user'] as Map<String, dynamic>) : null,
      );

  final int id;
  final int shares;
  final int? position;
  final MemberUser? user;

  String get displayName => user?.displayName ?? 'Membre';
}

class Tontine {
  const Tontine({
    required this.id,
    required this.organizationId,
    required this.name,
    required this.type,
    required this.amount,
    required this.frequency,
    required this.startsOn,
    required this.status,
    this.cyclesCount,
    this.maxMembers,
    this.goal,
    this.membersCount,
    this.amountDueTotal,
    this.amountPaidTotal,
    this.nextDueOn,
    this.members = const [],
  });

  factory Tontine.fromJson(Map<String, dynamic> json) => Tontine(
        id: asInt(json['id']),
        organizationId: asInt(json['organization_id']),
        name: '${json['name'] ?? ''}',
        type: TontineType.fromApi(json['type']),
        amount: asInt(json['amount']),
        frequency: Frequency.fromApi(json['frequency']),
        startsOn: asDate(json['starts_on']) ?? DateTime.now(),
        status: TontineStatus.fromApi(json['status']),
        cyclesCount: asIntOrNull(json['cycles_count']),
        maxMembers: asIntOrNull(json['max_members']),
        goal: asStringOrNull(json['goal']),
        membersCount: asIntOrNull(json['members_count']),
        amountDueTotal: asIntOrNull(json['amount_due_total']),
        amountPaidTotal: asIntOrNull(json['amount_paid_total']),
        nextDueOn: asDate(json['next_due_on']),
        members: asMapList(json['members']).map(TontineMember.fromJson).toList(),
      );

  final int id;
  final int organizationId;
  final String name;
  final TontineType type;
  final int amount;
  final Frequency frequency;
  final DateTime startsOn;
  final TontineStatus status;
  final int? cyclesCount;
  final int? maxMembers;
  final String? goal;
  final int? membersCount;
  final int? amountDueTotal;
  final int? amountPaidTotal;
  final DateTime? nextDueOn;
  final List<TontineMember> members;

  int get memberCount => membersCount ?? members.length;

  int get totalShares => members.fold(0, (sum, member) => sum + member.shares);

  /// Somme versée au bénéficiaire d'un tour, quand toutes les parts ont cotisé.
  int? get potPerCycle => type.hasBeneficiaries && members.isNotEmpty ? amount * totalShares : null;

  double get paidRatio {
    final due = amountDueTotal ?? 0;
    return due == 0 ? 0.0 : ((amountPaidTotal ?? 0) / due).clamp(0.0, 1.0);
  }

  bool get isDraft => status == TontineStatus.draft;
  bool get isActive => status == TontineStatus.active;
}

class Contribution {
  const Contribution({
    required this.id,
    required this.cycleId,
    required this.tontineMemberId,
    required this.amountDue,
    required this.amountPaid,
    required this.status,
    this.member,
    this.method,
    this.reference,
    this.paidAt,
    this.confirmedAt,
  });

  factory Contribution.fromJson(Map<String, dynamic> json) => Contribution(
        id: asInt(json['id']),
        cycleId: asInt(json['cycle_id']),
        tontineMemberId: asInt(json['tontine_member_id']),
        amountDue: asInt(json['amount_due']),
        amountPaid: asInt(json['amount_paid']),
        status: ContributionStatus.fromApi(json['status']),
        member: json['member'] is Map<String, dynamic> ? TontineMember.fromJson(json['member'] as Map<String, dynamic>) : null,
        method: PaymentMethod.fromApi(json['method']),
        reference: asStringOrNull(json['reference']),
        paidAt: asDate(json['paid_at']),
        confirmedAt: asDate(json['confirmed_at']),
      );

  final int id;
  final int cycleId;
  final int tontineMemberId;
  final int amountDue;
  final int amountPaid;
  final ContributionStatus status;
  final TontineMember? member;
  final PaymentMethod? method;
  final String? reference;
  final DateTime? paidAt;
  final DateTime? confirmedAt;

  bool get isFullyPaid => amountPaid >= amountDue;
}

class Cycle {
  const Cycle({
    required this.id,
    required this.number,
    required this.dueOn,
    required this.status,
    required this.amountDueTotal,
    required this.amountPaidTotal,
    this.beneficiary,
    this.contributions = const [],
  });

  factory Cycle.fromJson(Map<String, dynamic> json) => Cycle(
        id: asInt(json['id']),
        number: asInt(json['number']),
        dueOn: asDate(json['due_on']) ?? DateTime.now(),
        status: CycleStatus.fromApi(json['status']),
        amountDueTotal: asInt(json['amount_due_total']),
        amountPaidTotal: asInt(json['amount_paid_total']),
        beneficiary: json['beneficiary'] is Map<String, dynamic>
            ? TontineMember.fromJson(json['beneficiary'] as Map<String, dynamic>)
            : null,
        contributions: asMapList(json['contributions']).map(Contribution.fromJson).toList(),
      );

  final int id;
  final int number;
  final DateTime dueOn;
  final CycleStatus status;
  final int amountDueTotal;
  final int amountPaidTotal;
  final TontineMember? beneficiary;
  final List<Contribution> contributions;

  double get paidRatio => amountDueTotal == 0 ? 0.0 : (amountPaidTotal / amountDueTotal).clamp(0.0, 1.0);
}

/// Cotisation vue depuis l'échéancier personnel.
class MyContribution {
  const MyContribution({
    required this.contribution,
    required this.cycleNumber,
    required this.dueOn,
    required this.isLate,
    required this.isBeneficiary,
    required this.tontineId,
    required this.tontineName,
    required this.tontineType,
    required this.organizationId,
  });

  factory MyContribution.fromJson(Map<String, dynamic> json) {
    final tontine = asMap(json['tontine']);
    return MyContribution(
      contribution: Contribution.fromJson(json),
      cycleNumber: asInt(json['cycle_number']),
      dueOn: asDate(json['due_on']) ?? DateTime.now(),
      isLate: json['is_late'] == true,
      isBeneficiary: json['is_beneficiary'] == true,
      tontineId: asInt(tontine['id']),
      tontineName: '${tontine['name'] ?? ''}',
      tontineType: TontineType.fromApi(tontine['type']),
      organizationId: asInt(tontine['organization_id']),
    );
  }

  final Contribution contribution;
  final int cycleNumber;
  final DateTime dueOn;
  final bool isLate;
  final bool isBeneficiary;
  final int tontineId;
  final String tontineName;
  final TontineType tontineType;
  final int organizationId;

  bool get isSettled => contribution.status != ContributionStatus.pending && contribution.isFullyPaid;
}

/// Tour attribué par le responsable, publié avec l'empreinte et visible de tous.
class DrawDesignation {
  const DrawDesignation({required this.cycle, required this.slot});

  factory DrawDesignation.fromJson(Map<String, dynamic> json) =>
      DrawDesignation(cycle: asInt(json['cycle']), slot: '${json['slot'] ?? ''}');

  final int cycle;
  final String slot;

  int get memberId => Draw.memberIdOf(slot);
}

class Draw {
  const Draw({
    required this.id,
    required this.seedHash,
    required this.slots,
    required this.revealAfter,
    this.designations = const [],
    this.revealedAt,
    this.seed,
    this.order = const [],
  });

  factory Draw.fromJson(Map<String, dynamic> json) => Draw(
        id: asInt(json['id']),
        seedHash: '${json['seed_hash'] ?? ''}',
        slots: asStringList(json['slots']),
        designations: asMapList(json['designations']).map(DrawDesignation.fromJson).toList(),
        revealAfter: asDate(json['reveal_after']) ?? DateTime.now(),
        revealedAt: asDate(json['revealed_at']),
        seed: asStringOrNull(json['seed']),
        order: asStringList(json['order']),
      );

  final int id;
  final String seedHash;

  /// Parts tirées au sort, sans celles des tours attribués.
  final List<String> slots;
  final List<DrawDesignation> designations;
  final DateTime revealAfter;
  final DateTime? revealedAt;
  final String? seed;
  final List<String> order;

  int get cyclesCount => slots.length + designations.length;

  Set<int> get designatedCycles => {for (final designation in designations) designation.cycle};

  bool get isRevealed => revealedAt != null && seed != null;
  bool get canReveal => !isRevealed && !DateTime.now().isBefore(revealAfter);

  /// Une part « 12#2 » désigne la 2e part du membre 12.
  static int memberIdOf(String slot) => int.tryParse(slot.split('#').first) ?? 0;
}
