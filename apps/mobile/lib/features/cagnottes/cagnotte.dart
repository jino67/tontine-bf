import 'package:flutter/material.dart' show IconData, Icons;

import '../../core/json.dart';
import '../organizations/organization.dart';
import '../tontines/models.dart' show ContributionStatus, PaymentMethod;

enum CagnotteMode {
  solidarity('solidaire', 'Cagnotte solidaire', Icons.volunteer_activism_outlined),
  prize('gagnants', 'Cagnotte à gagnants', Icons.emoji_events_outlined);

  const CagnotteMode(this.apiValue, this.label, this.icon);

  final String apiValue;
  final String label;
  final IconData icon;

  static CagnotteMode fromApi(Object? value) =>
      values.firstWhere((mode) => mode.apiValue == value, orElse: () => solidarity);
}

enum CagnotteDuration {
  flash('flash_24h', 'Flash 24 h'),
  week('hebdo_7j', '7 jours'),
  month('mensuelle_30j', '30 jours'),
  custom('personnalisee', 'Date au choix');

  const CagnotteDuration(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static CagnotteDuration fromApi(Object? value) =>
      values.firstWhere((duration) => duration.apiValue == value, orElse: () => week);
}

enum CagnotteStatus {
  open('ouverte', 'Ouverte'),
  closed('cloturee', 'Clôturée'),
  handedOver('remise', 'Fonds remis'),
  drawn('tiree', 'Gagnants tirés'),
  cancelled('annulee', 'Annulée');

  const CagnotteStatus(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static CagnotteStatus fromApi(Object? value) =>
      values.firstWhere((status) => status.apiValue == value, orElse: () => open);
}

class CagnotteBeneficiary {
  const CagnotteBeneficiary({required this.name, this.userId});

  factory CagnotteBeneficiary.fromJson(Map<String, dynamic> json) =>
      CagnotteBeneficiary(name: asStringOrNull(json['name']) ?? 'Bénéficiaire', userId: asIntOrNull(json['user_id']));

  final String name;

  /// Null pour une personne extérieure à l'organisation.
  final int? userId;

  bool get isMember => userId != null;
}

class CagnotteHandover {
  const CagnotteHandover({required this.amount, required this.handedOverAt, this.method, this.reference, this.confirmedAt});

  factory CagnotteHandover.fromJson(Map<String, dynamic> json) => CagnotteHandover(
        amount: asInt(json['amount']),
        method: PaymentMethod.fromApi(json['method']),
        reference: asStringOrNull(json['reference']),
        handedOverAt: asDate(json['handed_over_at']) ?? DateTime.now(),
        confirmedAt: asDate(json['confirmed_at']),
      );

  final int amount;
  final PaymentMethod? method;
  final String? reference;
  final DateTime handedOverAt;
  final DateTime? confirmedAt;
}

/// Gain d'un rang, calculé sur la somme réunie. Un rang attribué affiche le nom du membre à tous.
class CagnottePrize {
  const CagnottePrize({required this.rank, required this.percent, required this.amount, this.designatedUserId, this.designatedName});

  factory CagnottePrize.fromJson(Map<String, dynamic> json) {
    final designated = json['designated_user'];
    return CagnottePrize(
      rank: asInt(json['rank']),
      percent: asDouble(json['percent']),
      amount: asInt(json['amount']),
      designatedUserId: designated is Map<String, dynamic> ? asInt(designated['id']) : null,
      designatedName: designated is Map<String, dynamic> ? asStringOrNull(designated['name']) : null,
    );
  }

  final int rank;
  final double percent;
  final int amount;
  final int? designatedUserId;
  final String? designatedName;

  bool get isDesignated => designatedUserId != null;
}

class CagnotteDraw {
  const CagnotteDraw({required this.seedHash, required this.tickets, required this.revealAfter, this.revealedAt, this.seed});

  factory CagnotteDraw.fromJson(Map<String, dynamic> json) => CagnotteDraw(
        seedHash: '${json['seed_hash'] ?? ''}',
        tickets: asStringList(json['tickets']),
        revealAfter: asDate(json['reveal_after']) ?? DateTime.now(),
        revealedAt: asDate(json['revealed_at']),
        seed: asStringOrNull(json['seed']),
      );

  final String seedHash;
  final List<String> tickets;
  final DateTime revealAfter;
  final DateTime? revealedAt;
  final String? seed;

  bool get isRevealed => revealedAt != null && seed != null;
  bool get canReveal => !isRevealed && !DateTime.now().isBefore(revealAfter);
}

class CagnotteWinner {
  const CagnotteWinner({
    required this.id,
    required this.rank,
    required this.prizeAmount,
    required this.designated,
    this.user,
    this.paidAt,
    this.paidMethod,
    this.paidReference,
    this.confirmedAt,
  });

  factory CagnotteWinner.fromJson(Map<String, dynamic> json) => CagnotteWinner(
        id: asInt(json['id']),
        rank: asInt(json['rank']),
        prizeAmount: asInt(json['prize_amount']),
        designated: json['designated'] == true,
        user: json['user'] is Map<String, dynamic> ? MemberUser.fromJson(json['user'] as Map<String, dynamic>) : null,
        paidAt: asDate(json['paid_at']),
        paidMethod: PaymentMethod.fromApi(json['paid_method']),
        paidReference: asStringOrNull(json['paid_reference']),
        confirmedAt: asDate(json['confirmed_at']),
      );

  final int id;
  final int rank;
  final int prizeAmount;
  final bool designated;
  final MemberUser? user;
  final DateTime? paidAt;
  final PaymentMethod? paidMethod;
  final String? paidReference;
  final DateTime? confirmedAt;
}

class CagnotteContribution {
  const CagnotteContribution({
    required this.id,
    required this.cagnotteId,
    required this.amount,
    required this.tickets,
    required this.status,
    this.user,
    this.method,
    this.reference,
    this.paidAt,
    this.confirmedAt,
  });

  factory CagnotteContribution.fromJson(Map<String, dynamic> json) => CagnotteContribution(
        id: asInt(json['id']),
        cagnotteId: asInt(json['cagnotte_id']),
        amount: asInt(json['amount']),
        tickets: asInt(json['tickets']),
        status: ContributionStatus.fromApi(json['status']),
        user: json['user'] is Map<String, dynamic> ? MemberUser.fromJson(json['user'] as Map<String, dynamic>) : null,
        method: PaymentMethod.fromApi(json['method']),
        reference: asStringOrNull(json['reference']),
        paidAt: asDate(json['paid_at']),
        confirmedAt: asDate(json['confirmed_at']),
      );

  final int id;
  final int cagnotteId;
  final int amount;
  final int tickets;
  final ContributionStatus status;
  final MemberUser? user;
  final PaymentMethod? method;
  final String? reference;
  final DateTime? paidAt;
  final DateTime? confirmedAt;
}

class Cagnotte {
  const Cagnotte({
    required this.id,
    required this.organizationId,
    required this.mode,
    required this.title,
    required this.duration,
    required this.minAmount,
    required this.opensAt,
    required this.endsAt,
    required this.deadline,
    required this.status,
    required this.acceptsContributions,
    required this.collectedAmount,
    this.description,
    this.targetAmount,
    this.beneficiary,
    this.contributionsCount,
    this.closedAt,
    this.handover,
    this.ticketPrice,
    this.winnersCount,
    this.feePercent = 0,
    this.ticketsCount = 0,
    this.myTickets,
    this.prizes = const [],
    this.draw,
    this.winners = const [],
    this.contributions = const [],
  });

  /// [now] sert au compte à rebours : il part des secondes restantes données par le serveur,
  /// pour ne pas dépendre de l'heure du téléphone.
  factory Cagnotte.fromJson(Map<String, dynamic> json, {DateTime? now}) {
    final endsAt = asDate(json['ends_at']) ?? DateTime.now();
    final secondsLeft = asInt(json['seconds_left']);
    final beneficiary = json['beneficiary'];
    final handover = json['handover'];
    final draw = json['draw'];

    return Cagnotte(
      id: asInt(json['id']),
      organizationId: asInt(json['organization_id']),
      mode: CagnotteMode.fromApi(json['mode']),
      title: '${json['title'] ?? ''}',
      description: asStringOrNull(json['description']),
      duration: CagnotteDuration.fromApi(json['duration']),
      targetAmount: asIntOrNull(json['target_amount']),
      minAmount: asInt(json['min_amount']),
      beneficiary: beneficiary is Map<String, dynamic> ? CagnotteBeneficiary.fromJson(beneficiary) : null,
      opensAt: asDate(json['opens_at']) ?? DateTime.now(),
      endsAt: endsAt,
      deadline: secondsLeft > 0 ? (now ?? DateTime.now()).add(Duration(seconds: secondsLeft)) : endsAt,
      status: CagnotteStatus.fromApi(json['status']),
      acceptsContributions: json['accepts_contributions'] == true,
      collectedAmount: asInt(json['collected_amount']),
      contributionsCount: asIntOrNull(json['contributions_count']),
      closedAt: asDate(json['closed_at']),
      handover: handover is Map<String, dynamic> ? CagnotteHandover.fromJson(handover) : null,
      ticketPrice: asIntOrNull(json['ticket_price']),
      winnersCount: asIntOrNull(json['winners_count']),
      feePercent: asInt(json['fee_percent']),
      ticketsCount: asInt(json['tickets_count']),
      myTickets: asIntOrNull(json['my_tickets']),
      prizes: asMapList(json['prizes']).map(CagnottePrize.fromJson).toList(),
      draw: draw is Map<String, dynamic> ? CagnotteDraw.fromJson(draw) : null,
      winners: asMapList(json['winners']).map(CagnotteWinner.fromJson).toList(),
      contributions: asMapList(json['contributions']).map(CagnotteContribution.fromJson).toList(),
    );
  }

  final int id;
  final int organizationId;
  final CagnotteMode mode;
  final String title;
  final String? description;
  final CagnotteDuration duration;
  final int? targetAmount;
  final int minAmount;
  final CagnotteBeneficiary? beneficiary;
  final DateTime opensAt;
  final DateTime endsAt;

  /// Fin de la collecte selon l'horloge du téléphone, pour le compte à rebours.
  final DateTime deadline;
  final CagnotteStatus status;
  final bool acceptsContributions;
  final int collectedAmount;
  final int? contributionsCount;
  final DateTime? closedAt;
  final CagnotteHandover? handover;
  final int? ticketPrice;
  final int? winnersCount;
  final int feePercent;
  final int ticketsCount;
  final int? myTickets;
  final List<CagnottePrize> prizes;
  final CagnotteDraw? draw;
  final List<CagnotteWinner> winners;
  final List<CagnotteContribution> contributions;

  bool get isPrize => mode == CagnotteMode.prize;
  bool get isOpen => status == CagnotteStatus.open;

  int get participationsCount => contributionsCount ?? contributions.length;

  /// Rangs attribués par le responsable : rang, puis identifiant du membre.
  Map<int, int> get designations => {
        for (final prize in prizes)
          if (prize.designatedUserId != null) prize.rank: prize.designatedUserId!,
      };

  /// Les participations ne se modifient plus une fois les fonds remis ou le tirage lancé.
  bool get isLocked => status == CagnotteStatus.handedOver || draw != null;

  double? get targetRatio =>
      targetAmount == null || targetAmount == 0 ? null : (collectedAmount / targetAmount!).clamp(0.0, 1.0);
}
