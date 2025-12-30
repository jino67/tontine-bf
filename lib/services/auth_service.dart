import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';

class AuthService {
  // VOTRE VRAIE URL
  static const String baseUrl = 'https://poupecosmetic.com/api/auth_api.php';

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

  // NOUVELLE MÉTHODE : Vérifier si l'utilisateur est admin
  Future<bool> isUserAdmin() async {
    final user = await getCurrentUser();
    print('=== DEBUG isUserAdmin ===');
    print('User: $user');
    print('User isVerified: ${user?.isVerified}');
    print('User isVerified type: ${user?.isVerified?.runtimeType}');
    return user?.isVerified == true;
  }

  Future<void> login(String telephone, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth_api.php'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'action': 'login',
          'phone_number': telephone,
          'password': password,
        }),
      );

      print('=== DEBUG LOGIN START ===');
      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['success'] == true) {
          await init();

          // DEBUG: Afficher TOUTES les données user reçues
          print('=== USER DATA RECEIVED ===');
          print('User object: ${data['user']}');
          print('User keys: ${data['user']?.keys.toList()}');
          print('User is_verified: ${data['user']?['is_verified']}');
          print('User is_verified type: ${data['user']?['is_verified']?.runtimeType}');

          // CRÉER L'OBJET USER AVEC is_verified
          final user = User.fromJson(data['user']);

          // Stockez les informations utilisateur
          await _prefs.setString('user_token', 'token_${DateTime.now().millisecondsSinceEpoch}');
          await _prefs.setString('user_id', data['user']['id'].toString());
          await _prefs.setString('current_user', json.encode(data['user']));

          // DEBUG FINAL
          print('=== FINAL USER OBJECT ===');
          print('User ID: ${user.id}');
          print('User Name: ${user.fullName}');
          print('User Phone: ${user.phoneNumber}');
          print('User isVerified: ${user.isVerified}');
          print('User isVerified type: ${user.isVerified.runtimeType}');
          print('=== DEBUG LOGIN END ===');
        } else {
          throw Exception(data['message']);
        }
      } else {
        throw Exception('Erreur serveur: ${response.statusCode}');
      }
    } catch (e) {
      print('Login error: $e');
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
      final response = await http.post(
        Uri.parse('$baseUrl/auth_api.php'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'action': 'register',
          'full_name': fullName,
          'phone_number': phoneNumber,
          'email': email.isNotEmpty ? email : '',
          'password': password,
        }),
      );

      print('Register response status: ${response.statusCode}');
      print('Register response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (!data['success']) {
          throw Exception(data['message']);
        }
      } else {
        throw Exception('Erreur serveur: ${response.statusCode}');
      }
    } catch (e) {
      print('Register error: $e');
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
      final response = await http.post(
        Uri.parse('$baseUrl/auth_api.php'),
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

  // NOUVELLE MÉTHODE : Rafraîchir les infos utilisateur
  Future<void> refreshUserData() async {
    try {
      final userId = await getUserId();
      if (userId == null) return;

      // Appel API pour récupérer les dernières infos utilisateur
      final response = await http.post(
        Uri.parse('$baseUrl/auth_api.php'),
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
      print('Erreur refreshUserData: $e');
    }
  }

  // MÉTHODE DE DEBUG : Afficher toutes les données stockées
  Future<void> debugStoredData() async {
    await init();
    print('=== DEBUG STORED DATA ===');
    print('user_token: ${_prefs.getString('user_token')}');
    print('user_id: ${_prefs.getString('user_id')}');

    final userJson = _prefs.getString('current_user');
    print('current_user: $userJson');

    if (userJson != null) {
      final userMap = json.decode(userJson);
      print('current_user decoded: $userMap');
      print('current_user is_verified: ${userMap['is_verified']}');
    }
  }
}