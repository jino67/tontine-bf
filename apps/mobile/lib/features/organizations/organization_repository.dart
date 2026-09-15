import '../../core/api/api_client.dart';
import '../../core/json.dart';
import 'organization.dart';

class OrganizationRepository {
  OrganizationRepository(this._api);

  final ApiClient _api;

  Future<List<Organization>> list() async =>
      asMapList(unwrap(await _api.get('/orgs'))).map(Organization.fromJson).toList();

  Future<Organization> create(String name) async =>
      Organization.fromJson(asMap(unwrap(await _api.post('/orgs', {'name': name}))));

  Future<List<Membership>> members(int organizationId) async =>
      asMapList(unwrap(await _api.get('/orgs/$organizationId/members'))).map(Membership.fromJson).toList();

  Future<Membership> updateRole(int organizationId, int membershipId, Role role) async {
    final body = await _api.patch('/orgs/$organizationId/members/$membershipId', {'role': role.apiValue});
    return Membership.fromJson(asMap(unwrap(body)));
  }

  Future<Invitation> createInvitation(int organizationId, {int? tontineId, int expiresInDays = 7}) async {
    final body = await _api.post('/orgs/$organizationId/invitations', {
      'tontine_id': ?tontineId,
      'expires_in_days': expiresInDays,
    });
    return Invitation.fromJson(asMap(unwrap(body)));
  }

  Future<JoinResult> acceptInvitation(String code) async {
    final body = asMap(await _api.post('/invitations/${Uri.encodeComponent(code.trim().toUpperCase())}/accept'));
    final tontine = body['tontine'];
    return JoinResult(
      organization: Organization.fromJson(asMap(body['organization'])),
      tontineName: tontine is Map<String, dynamic> ? asStringOrNull(tontine['name']) : null,
    );
  }
}
