import '../../core/api/api_client.dart';
import '../../core/json.dart';
import 'fees.dart';

/// Grille des frais et simulation avant paiement.
class FeesRepository {
  FeesRepository(this._api, {this.organizationId});

  final ApiClient _api;
  final int? organizationId;

  Future<FeeGrid> grid() async {
    final suffix = organizationId == null ? '' : '?organization_id=$organizationId';

    return FeeGrid.fromJson(asMap(unwrap(await _api.get('/fees$suffix'))));
  }

  Future<FeeQuote> simulate({required String operation, required int amount}) async => FeeQuote.fromJson(
        asMap(unwrap(await _api.post('/fees/simulate', {
          'operation': operation,
          'amount': amount,
          'organization_id': ?organizationId,
        }))),
      );
}
