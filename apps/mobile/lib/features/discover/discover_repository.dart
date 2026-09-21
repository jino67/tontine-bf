import '../../core/api/api_client.dart';
import '../../core/json.dart';
import '../sharing/sharing.dart';
import 'join_request.dart';

/// Résultats de l'annuaire public.
class DiscoverResults {
  const DiscoverResults({required this.tontines, required this.cagnottes});

  final List<SharedLink> tontines;
  final List<SharedLink> cagnottes;

  bool get isEmpty => tontines.isEmpty && cagnottes.isEmpty;
}

/// Annuaire public, demandes d'adhésion et signalements.
class DiscoverRepository {
  DiscoverRepository(this._api);

  final ApiClient _api;

  Future<DiscoverResults> search({String? query, int? maxAmount}) async {
    final parameters = <String, String>{
      if ((query ?? '').trim().isNotEmpty) 'q': query!.trim(),
      if (maxAmount != null) 'max_amount': '$maxAmount',
    };
    final suffix = parameters.isEmpty
        ? ''
        : '?${parameters.entries.map((entry) => '${entry.key}=${Uri.encodeQueryComponent(entry.value)}').join('&')}';
    final data = asMap(unwrap(await _api.get('/discover$suffix')));

    return DiscoverResults(
      tontines: asMapList(data['tontines']).map((item) => SharedLink(type: 'tontine', data: item)).toList(),
      cagnottes: asMapList(data['cagnottes']).map((item) => SharedLink(type: 'cagnotte', data: item)).toList(),
    );
  }

  /// Retourne la demande créée, ou null quand l'adhésion est libre et l'entrée immédiate.
  Future<JoinRequestSummary?> requestJoin({required String type, required int id, String? message}) async {
    final body = asMap(await _api.post('/join-requests', {'type': type, 'id': id, 'message': ?message}));

    return body['data'] is Map<String, dynamic> ? JoinRequestSummary.fromJson(asMap(body['data'])) : null;
  }

  Future<List<JoinRequestSummary>> mine() async =>
      asMapList(unwrap(await _api.get('/join-requests'))).map(JoinRequestSummary.fromJson).toList();

  Future<void> withdraw(int id) => _api.delete('/join-requests/$id');

  Future<void> report({required String type, required int id, required ReportReason reason, String? note}) =>
      _api.post('/reports', {'type': type, 'id': id, 'reason': reason.apiValue, 'note': ?note});

  /// Côté responsables.
  Future<List<JoinRequestSummary>> pending(int organizationId) async =>
      asMapList(unwrap(await _api.get('/orgs/$organizationId/join-requests'))).map(JoinRequestSummary.fromJson).toList();

  Future<JoinRequestSummary> approve(int organizationId, int id) async => JoinRequestSummary.fromJson(
        asMap(unwrap(await _api.post('/orgs/$organizationId/join-requests/$id/approve'))),
      );

  Future<JoinRequestSummary> reject(int organizationId, int id, {String? reason}) async => JoinRequestSummary.fromJson(
        asMap(unwrap(await _api.post('/orgs/$organizationId/join-requests/$id/reject', {'reason': ?reason}))),
      );
}
