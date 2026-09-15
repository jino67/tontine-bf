import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Ce que l'app retient entre deux lancements.
abstract class SessionStore {
  Future<String?> readToken();
  Future<void> writeToken(String token);
  Future<int?> readOrganizationId();
  Future<void> writeOrganizationId(int? id);
  Future<bool> readOnboardingSeen();
  Future<void> writeOnboardingSeen();
  Future<void> clearSession();
}

/// Jeton dans le stockage chiffré du téléphone, préférences simples dans SharedPreferences.
class DeviceSessionStore implements SessionStore {
  static const _tokenKey = 'api_token';
  static const _organizationKey = 'current_organization_id';
  static const _onboardingKey = 'onboarding_seen';

  final _secure = const FlutterSecureStorage();

  @override
  Future<String?> readToken() => _secure.read(key: _tokenKey);

  @override
  Future<void> writeToken(String token) => _secure.write(key: _tokenKey, value: token);

  @override
  Future<int?> readOrganizationId() async => (await SharedPreferences.getInstance()).getInt(_organizationKey);

  @override
  Future<void> writeOrganizationId(int? id) async {
    final preferences = await SharedPreferences.getInstance();
    if (id == null) {
      await preferences.remove(_organizationKey);
    } else {
      await preferences.setInt(_organizationKey, id);
    }
  }

  @override
  Future<bool> readOnboardingSeen() async => (await SharedPreferences.getInstance()).getBool(_onboardingKey) ?? false;

  @override
  Future<void> writeOnboardingSeen() async => (await SharedPreferences.getInstance()).setBool(_onboardingKey, true);

  @override
  Future<void> clearSession() async {
    await _secure.delete(key: _tokenKey);
    await writeOrganizationId(null);
  }
}

/// Stockage en mémoire, pour les tests.
class MemorySessionStore implements SessionStore {
  MemorySessionStore({this.token, this.organizationId, this.onboardingSeen = true});

  String? token;
  int? organizationId;
  bool onboardingSeen;

  @override
  Future<String?> readToken() async => token;

  @override
  Future<void> writeToken(String value) async => token = value;

  @override
  Future<int?> readOrganizationId() async => organizationId;

  @override
  Future<void> writeOrganizationId(int? id) async => organizationId = id;

  @override
  Future<bool> readOnboardingSeen() async => onboardingSeen;

  @override
  Future<void> writeOnboardingSeen() async => onboardingSeen = true;

  @override
  Future<void> clearSession() async {
    token = null;
    organizationId = null;
  }
}
