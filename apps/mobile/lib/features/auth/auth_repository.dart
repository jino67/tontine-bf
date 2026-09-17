import '../../core/api/api_client.dart';
import '../../core/json.dart';
import 'user.dart';

/// Où le code de connexion est parti, tel que l'annonce l'API.
class OtpDelivery {
  const OtpDelivery({required this.channel, this.destination});

  factory OtpDelivery.fromJson(Map<String, dynamic> json) =>
      OtpDelivery(channel: '${json['channel'] ?? ''}', destination: asStringOrNull(json['destination']));

  /// mail, test ou log (développement).
  final String channel;

  /// Adresse e-mail masquée, pour le canal mail.
  final String? destination;
}

class AuthRepository {
  AuthRepository(this._api);

  final ApiClient _api;

  /// [email] n'est utile qu'à la première connexion : ensuite, le code part à l'adresse liée au numéro.
  Future<OtpDelivery> requestOtp(String phone, {String? email}) async =>
      OtpDelivery.fromJson(asMap(await _api.post('/auth/otp/request', {'phone': phone, 'email': ?email})));

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
