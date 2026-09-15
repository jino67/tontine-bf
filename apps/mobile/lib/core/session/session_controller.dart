import 'package:flutter/foundation.dart';

import '../../features/auth/auth_repository.dart';
import '../../features/auth/user.dart';
import '../../features/organizations/organization.dart';
import '../../features/organizations/organization_repository.dart';
import '../api/api_client.dart';
import '../api/api_exception.dart';
import 'session_store.dart';

enum SessionStatus { loading, onboarding, signedOut, signedIn, unreachable }

/// État de connexion, utilisateur et organisation courante.
class SessionController extends ChangeNotifier {
  SessionController({required this.api, required this.store})
      : auth = AuthRepository(api),
        organizations = OrganizationRepository(api) {
    api.onUnauthorized = _onUnauthorized;
  }

  final ApiClient api;
  final SessionStore store;
  final AuthRepository auth;
  final OrganizationRepository organizations;

  SessionStatus _status = SessionStatus.loading;
  User? _user;
  List<Organization> _organizations = const [];
  Organization? _current;
  String? _errorMessage;

  SessionStatus get status => _status;
  User? get user => _user;
  List<Organization> get organizationList => _organizations;
  Organization? get currentOrganization => _current;
  String? get errorMessage => _errorMessage;
  bool get needsProfile => (_user?.name ?? '').trim().isEmpty;

  Future<void> restore() async {
    _status = SessionStatus.loading;
    notifyListeners();

    if (!await store.readOnboardingSeen()) {
      _status = SessionStatus.onboarding;
      notifyListeners();
      return;
    }

    final token = await store.readToken();
    if (token == null) {
      _status = SessionStatus.signedOut;
      notifyListeners();
      return;
    }

    api.token = token;
    try {
      await _loadAccount(await store.readOrganizationId());
      _status = SessionStatus.signedIn;
    } on ApiException catch (error) {
      if (error.isUnauthorized) {
        await _forget();
      } else {
        _errorMessage = error.message;
        _status = SessionStatus.unreachable;
      }
    }
    notifyListeners();
  }

  Future<void> completeOnboarding() async {
    await store.writeOnboardingSeen();
    await restore();
  }

  Future<void> signIn({required String phone, required String code}) async {
    final token = await auth.verifyOtp(phone: phone, code: code);
    api.token = token;
    await store.writeToken(token);
    await _loadAccount(await store.readOrganizationId());
    _status = SessionStatus.signedIn;
    notifyListeners();
  }

  Future<void> updateProfile({required String name, String? email}) async {
    _user = await auth.updateMe(name: name, email: email);
    notifyListeners();
  }

  Future<void> reloadOrganizations({int? select}) async {
    _organizations = await organizations.list();
    _current = _choose(select ?? _current?.id);
    await store.writeOrganizationId(_current?.id);
    notifyListeners();
  }

  Future<void> selectOrganization(Organization organization) async {
    _current = organization;
    await store.writeOrganizationId(organization.id);
    notifyListeners();
  }

  /// Revient à la liste des organisations.
  Future<void> switchOrganization() async {
    _current = null;
    await store.writeOrganizationId(null);
    notifyListeners();
  }

  Future<void> signOut() async {
    try {
      await auth.logout();
    } on ApiException {
      // Le jeton est oublié sur le téléphone dans tous les cas.
    }
    await _forget();
    notifyListeners();
  }

  Future<void> _loadAccount(int? preferredOrganizationId) async {
    _user = await auth.me();
    _organizations = await organizations.list();
    _current = _choose(preferredOrganizationId);
  }

  Organization? _choose(int? id) {
    for (final organization in _organizations) {
      if (organization.id == id) return organization;
    }
    return _organizations.length == 1 ? _organizations.first : null;
  }

  Future<void> _forget() async {
    api.token = null;
    _user = null;
    _organizations = const [];
    _current = null;
    _status = SessionStatus.signedOut;
    await store.clearSession();
  }

  void _onUnauthorized() {
    if (_status != SessionStatus.signedIn) return;
    _forget().then((_) => notifyListeners());
  }
}
