import '../../core/api/api_client.dart';
import '../../core/json.dart';
import 'user.dart';

class AuthRepository {
  AuthRepository(this._api);

  final ApiClient _api;

  Future<void> requestOtp(String phone) async {
    await _api.post('/auth/otp/request', {'phone': phone});
  }

  /// Retourne le jeton d'accès.
  Future<String> verifyOtp({required String phone, required String code}) async {
    final body = asMap(await _api.post('/auth/otp/verify', {
      'phone': phone,
      'code': code,
      'device_name': 'Application Tontine BF',
    }));
    return '${body['token']}';
  }

  Future<User> me() async => User.fromJson(asMap(unwrap(await _api.get('/me'))));

  Future<User> updateMe({required String name, String? email}) async {
    final body = await _api.patch('/me', {'name': name, 'email': email});
    return User.fromJson(asMap(unwrap(body)));
  }

  Future<void> logout() async {
    await _api.post('/auth/logout');
  }
}
