import 'package:flutter/foundation.dart';

import '../../core/api/api_client.dart';
import '../../core/json.dart';
import '../tontines/models.dart' show PaymentMethod;
import 'cagnotte.dart';

/// Formule préparée depuis le back-office, proposée à la création d'une cagnotte.
class CagnotteTemplate {
  const CagnotteTemplate({
    required this.id,
    required this.name,
    required this.mode,
    required this.duration,
    required this.recurring,
    this.description,
    this.ticketPrice,
    this.winnersCount,
    this.minAmount,
    this.targetAmount,
    this.feePercent = 0,
  });

  factory CagnotteTemplate.fromJson(Map<String, dynamic> json) => CagnotteTemplate(
        id: asInt(json['id']),
        name: '${json['name']}',
        mode: CagnotteMode.fromApi(json['mode']),
        duration: CagnotteDuration.fromApi(json['duration']),
        recurring: json['recurring'] == true,
        description: asStringOrNull(json['description']),
        ticketPrice: asIntOrNull(json['ticket_price']),
        winnersCount: asIntOrNull(json['winners_count']),
        minAmount: asIntOrNull(json['min_amount']),
        targetAmount: asIntOrNull(json['target_amount']),
        feePercent: asInt(json['fee_percent']),
      );

  final int id;
  final String name;
  final CagnotteMode mode;
  final CagnotteDuration duration;
  final bool recurring;
  final String? description;
  final int? ticketPrice;
  final int? winnersCount;
  final int? minAmount;
  final int? targetAmount;
  final int feePercent;
}

class CagnotteDraft {
  const CagnotteDraft({
    required this.mode,
    required this.title,
    required this.duration,
    this.description,
    this.endsAt,
    this.targetAmount,
    this.minAmount,
    this.beneficiaryUserId,
    this.beneficiaryName,
    this.ticketPrice,
    this.winnersCount,
    this.feePercent,
    this.recurring = false,
    this.templateId,
  });

  final CagnotteMode mode;
  final String title;
  final CagnotteDuration duration;
  final String? description;
  final DateTime? endsAt;
  final int? targetAmount;
  final int? minAmount;
  final int? beneficiaryUserId;
  final String? beneficiaryName;
  final int? ticketPrice;
  final int? winnersCount;
  final int? feePercent;

  /// Une cagnotte récurrente ouvre son édition suivante dès que le tirage est révélé.
  final bool recurring;

  /// Modèle dont viennent les valeurs, gardé pour l'historique.
  final int? templateId;

  Map<String, dynamic> toJson() => {
        'mode': mode.apiValue,
        'title': title,
        'recurring': recurring,
        'template_id': templateId,
        'description': description,
        'duration': duration.apiValue,
        if (duration == CagnotteDuration.custom) 'ends_at': endsAt?.toUtc().toIso8601String(),
        'target_amount': targetAmount,
        if (mode == CagnotteMode.solidarity) ...{
          'min_amount': minAmount,
          'beneficiary_user_id': beneficiaryUserId,
          'beneficiary_name': beneficiaryName,
        },
        if (mode == CagnotteMode.prize) ...{
          'ticket_price': ticketPrice,
          'winners_count': winnersCount,
          'fee_percent': feePercent ?? 0,
        },
      };
}

/// Cagnottes de l'organisation courante.
class CagnotteRepository {
  CagnotteRepository(this._api, this.organizationId);

  final ApiClient _api;
  final int organizationId;

  /// Incrémenté après chaque modification : les écrans à l'écoute se rechargent.
  final revision = ValueNotifier<int>(0);

  String get _base => '/orgs/$organizationId/cagnottes';

  Cagnotte _changed(Object? body) {
    revision.value++;
    return Cagnotte.fromJson(asMap(unwrap(body)));
  }

  static String? _clean(String? text) => (text ?? '').trim().isEmpty ? null : text!.trim();

  Future<List<Cagnotte>> list() async {
    final now = DateTime.now();
    return asMapList(unwrap(await _api.get(_base))).map((json) => Cagnotte.fromJson(json, now: now)).toList();
  }

  Future<Cagnotte> get(int cagnotteId) async => Cagnotte.fromJson(asMap(unwrap(await _api.get('$_base/$cagnotteId'))));

  Future<Cagnotte> create(CagnotteDraft draft) async => _changed(await _api.post(_base, draft.toJson()));

  /// Formules préparées depuis le back-office. La liste peut être vide : rien n'y oblige.
  Future<List<CagnotteTemplate>> templates() async =>
      asMapList(unwrap(await _api.get('/cagnotte-templates'))).map(CagnotteTemplate.fromJson).toList();

  Future<Cagnotte> close(int cagnotteId) async => _changed(await _api.post('$_base/$cagnotteId/close'));

  Future<void> recordContribution(
    int cagnotteId, {
    required int userId,
    required int amount,
    required PaymentMethod method,
    String? reference,
  }) async {
    await _api.post('$_base/$cagnotteId/contributions', {
      'user_id': userId,
      'amount': amount,
      'method': method.apiValue,
      'reference': _clean(reference),
    });
    revision.value++;
  }

  Future<void> updateContribution(
    int cagnotteId,
    int contributionId, {
    required int amount,
    required PaymentMethod method,
    String? reference,
  }) async {
    await _api.put('$_base/$cagnotteId/contributions/$contributionId', {
      'amount': amount,
      'method': method.apiValue,
      'reference': _clean(reference),
    });
    revision.value++;
  }

  Future<void> confirmContribution(int cagnotteId, int contributionId) async {
    await _api.post('$_base/$cagnotteId/contributions/$contributionId/confirm');
    revision.value++;
  }

  /// Avec [PaymentMethod.paydunya], [withdrawMode] et [phone] désignent le compte mobile money qui reçoit les fonds.
  Future<Cagnotte> recordHandover(
    int cagnotteId, {
    required int amount,
    required PaymentMethod method,
    String? reference,
    String? withdrawMode,
    String? phone,
  }) async =>
      _changed(await _api.post('$_base/$cagnotteId/handover', {
        'amount': amount,
        'method': method.apiValue,
        'reference': _clean(reference),
        'withdraw_mode': ?withdrawMode,
        'phone': ?phone,
      }));

  Future<Cagnotte> confirmHandover(int cagnotteId) async => _changed(await _api.post('$_base/$cagnotteId/handover/confirm'));

  Future<Cagnotte> commitDraw(int cagnotteId, DateTime revealAfter) async =>
      _changed(await _api.post('$_base/$cagnotteId/draw', {'reveal_after': revealAfter.toUtc().toIso8601String()}));

  Future<Cagnotte> revealDraw(int cagnotteId) async => _changed(await _api.post('$_base/$cagnotteId/draw/reveal'));

  Future<Cagnotte> recordPayout(
    int cagnotteId,
    int winnerId, {
    required PaymentMethod method,
    String? reference,
    String? withdrawMode,
    String? phone,
  }) async =>
      _changed(await _api.post('$_base/$cagnotteId/winners/$winnerId/payout', {
        'method': method.apiValue,
        'reference': _clean(reference),
        'withdraw_mode': ?withdrawMode,
        'phone': ?phone,
      }));

  Future<Cagnotte> confirmPayout(int cagnotteId, int winnerId) async =>
      _changed(await _api.post('$_base/$cagnotteId/winners/$winnerId/confirm'));
}
