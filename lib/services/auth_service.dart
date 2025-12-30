import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';

class AuthService {
  // CORRECTION CRITIQUE : Utiliser l'URL complète de l'endpoint
  static const String apiEndpoint = 'https://poupecosmetic.com/api/auth_api.php';

  // Le reste de la classe SharedPreferences est correct
  late SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  Future<bool> isLoggedIn() async {
    await init();
    return _prefs.getString('user_token') != null;
  }

  Future<String?> getToken() async {
    await init();
    return _prefs.getString('user_token');
  }

  // Cette méthode est correcte : elle récupère l'ID stocké
  Future<String?> getUserId() async {
    await init();
    return _prefs.getString('user_id');
  }

  Future<User?> getCurrentUser() async {
    await init();
    final userJson = _prefs.getString('current_user');
    if (userJson != null) {
      return User.fromJson(json.decode(userJson));
    }
    return null;
  }

  Future<bool> isUserAdmin() async {
    final user = await getCurrentUser();
    return user?.isVerified == true;
  }

  Future<void> login(String telephone, String password) async {
    try {
      // CORRECTION : Utilisation de apiEndpoint
      final response = await http.post(
        Uri.parse(apiEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'action': 'login',
          'phone_number': telephone,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['success'] == true) {
          await init();

          // CORRECTION/NETTOYAGE : S'assurer que 'id' est un String avant le stockage
          final userId = data['user']['id'].toString();

          await _prefs.setString('user_token', 'token_${DateTime.now().millisecondsSinceEpoch}');
          await _prefs.setString('user_id', userId);
          await _prefs.setString('current_user', json.encode(data['user']));

        } else {
          throw Exception(data['message']);
        }
      } else {
        throw Exception('Erreur serveur: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Erreur de connexion: $e');
    }
  }

  Future<void> register({
    required String fullName,
    required String phoneNumber,
    required String email,
    required String password,
  }) async {
    try {
      // CORRECTION : Utilisation de apiEndpoint
      final response = await http.post(
        Uri.parse(apiEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'action': 'register',
          'full_name': fullName,
          'phone_number': phoneNumber,
          'email': email.isNotEmpty ? email : '',
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (!data['success']) {
          throw Exception(data['message']);
        }
      } else {
        throw Exception('Erreur serveur: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Erreur d\'inscription: $e');
    }
  }

  Future<void> logout() async {
    await init();
    await _prefs.remove('user_token');
    await _prefs.remove('user_id');
    await _prefs.remove('current_user');
  }

  Future<void> resetPassword(String telephone) async {
    try {
      // CORRECTION : Utilisation de apiEndpoint
      final response = await http.post(
        Uri.parse(apiEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'action': 'reset_password',
          'phone_number': telephone,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (!data['success']) {
          throw Exception(data['message']);
        }
      } else {
        throw Exception('Erreur de réinitialisation');
      }
    } catch (e) {
      throw Exception('Erreur: $e');
    }
  }

  Future<void> refreshUserData() async {
    try {
      final userId = await getUserId();
      if (userId == null) return;

      // CORRECTION : Utilisation de apiEndpoint
      final response = await http.post(
        Uri.parse(apiEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'action': 'get_user_info',
          'user_id': userId,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          await init();
          await _prefs.setString('current_user', json.encode(data['user']));
        }
      }
    } catch (e) {
      // Gérer l'erreur
    }
  }

  Future<void> debugStoredData() async {
    // Méthode de debug conservée
  }
}