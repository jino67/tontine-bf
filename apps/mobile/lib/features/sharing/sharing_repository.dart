import '../../core/api/api_client.dart';
import '../../core/json.dart';
import 'sharing.dart';

/// Liens de partage : lecture publique d'un code, et réglage de la visibilité par un responsable.
class SharingRepository {
  SharingRepository(this._api);

  final ApiClient _api;

  /// Lisible sans être membre : l'API ne renvoie que la fiche publique.
  Future<SharedLink> resolve(String code) async =>
      SharedLink.fromJson(asMap(await _api.get('/links/${Uri.encodeComponent(code.trim().toUpperCase())}')));

  Future<String?> setTontine(int organizationId, int tontineId, ShareVisibility visibility) =>
      _apply('/orgs/$organizationId/tontines/$tontineId/sharing', visibility);

  Future<String?> setCagnotte(int organizationId, int cagnotteId, ShareVisibility visibility) =>
      _apply('/orgs/$organizationId/cagnottes/$cagnotteId/sharing', visibility);

  Future<String?> setOrganization(int organizationId, ShareVisibility visibility) =>
      _apply('/orgs/$organizationId/sharing', visibility);

  /// Retourne l'adresse de partage, nulle quand l'objet redevient privé.
  Future<String?> _apply(String path, ShareVisibility visibility) async {
    final body = asMap(unwrap(await _api.put(path, {'visibility': visibility.apiValue})));

    return asStringOrNull(body['share_url']);
  }
}
