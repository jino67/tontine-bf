import 'package:flutter/foundation.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_exception.dart';
import '../../core/format.dart';
import '../../core/json.dart';
import 'models.dart';

class TontineDraft {
  const TontineDraft({
    required this.name,
    required this.type,
    required this.amount,
    required this.frequency,
    required this.startsOn,
    this.cyclesCount,
    this.maxMembers,
    this.goal,
    this.creatorJoins = true,
  });

  final String name;
  final TontineType type;
  final int amount;
  final Frequency frequency;
  final DateTime startsOn;
  final int? cyclesCount;
  final int? maxMembers;
  final String? goal;
  final bool creatorJoins;

  Map<String, dynamic> toJson() => {
        'name': name,
        'type': type.apiValue,
        'amount': amount,
        'frequency': frequency.apiValue,
        'starts_on': apiDate(startsOn),
        if (!type.hasBeneficiaries) 'cycles_count': cyclesCount,
        if (type != TontineType.personalSavings) 'max_members': maxMembers,
        'goal': goal,
        'creator_joins': creatorJoins,
      };
}

/// Tontines de l'organisation courante.
class TontineRepository {
  TontineRepository(this._api, this.organizationId);

  final ApiClient _api;
  final int organizationId;

  /// Incrémenté après chaque modification : les écrans à l'écoute se rechargent.
  final revision = ValueNotifier<int>(0);

  String get _base => '/orgs/$organizationId/tontines';

  T _changed<T>(T result) {
    revision.value++;
    return result;
  }

  Future<List<Tontine>> list() async => asMapList(unwrap(await _api.get(_base))).map(Tontine.fromJson).toList();

  Future<Tontine> get(int tontineId) async => Tontine.fromJson(asMap(unwrap(await _api.get('$_base/$tontineId'))));

  Future<Tontine> create(TontineDraft draft) async =>
      _changed(Tontine.fromJson(asMap(unwrap(await _api.post(_base, draft.toJson())))));

  Future<Tontine> start(int tontineId) async =>
      _changed(Tontine.fromJson(asMap(unwrap(await _api.post('$_base/$tontineId/start')))));

  Future<List<Cycle>> cycles(int tontineId) async =>
      asMapList(unwrap(await _api.get('$_base/$tontineId/cycles'))).map(Cycle.fromJson).toList();

  Future<Cycle> cycle(int tontineId, int cycleId) async =>
      Cycle.fromJson(asMap(unwrap(await _api.get('$_base/$tontineId/cycles/$cycleId'))));

  Future<Contribution> recordPayment(
    int tontineId,
    Contribution contribution, {
    required int amountPaid,
    PaymentMethod? method,
    String? reference,
  }) async {
    final body = await _api.put('$_base/$tontineId/cycles/${contribution.cycleId}/contributions/${contribution.id}', {
      'amount_paid': amountPaid,
      'method': method?.apiValue,
      'reference': (reference ?? '').trim().isEmpty ? null : reference!.trim(),
    });
    return _changed(Contribution.fromJson(asMap(unwrap(body))));
  }

  Future<Contribution> confirmPayment(int tontineId, Contribution contribution) async {
    final body = await _api.post('$_base/$tontineId/cycles/${contribution.cycleId}/contributions/${contribution.id}/confirm');
    return _changed(Contribution.fromJson(asMap(unwrap(body))));
  }

  /// Null tant qu'aucun tirage n'a été lancé.
  Future<Draw?> draw(int tontineId) async {
    try {
      return Draw.fromJson(asMap(unwrap(await _api.get('$_base/$tontineId/draw'))));
    } on ApiException catch (error) {
      if (error.isNotFound) return null;
      rethrow;
    }
  }

  Future<Draw> commitDraw(int tontineId, DateTime revealAfter) async {
    final body = await _api.post('$_base/$tontineId/draw', {'reveal_after': revealAfter.toUtc().toIso8601String()});
    return _changed(Draw.fromJson(asMap(unwrap(body))));
  }

  Future<Draw> revealDraw(int tontineId) async =>
      _changed(Draw.fromJson(asMap(unwrap(await _api.post('$_base/$tontineId/draw/reveal')))));

  Future<List<MyContribution>> myContributions() async {
    final body = await _api.get('/me/contributions?organization_id=$organizationId');
    return asMapList(unwrap(body)).map(MyContribution.fromJson).toList();
  }
}
