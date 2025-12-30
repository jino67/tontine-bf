// lib/features/cagnotte/services/tirage_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/tirage_config_model.dart';
import '../models/gagnant_model.dart';

class TirageService {
  static const String baseUrl = 'https://poupecosmetic.com/api';

  // Pour l'admin - configurer le tirage hybride
  Future<Map<String, dynamic>> configurerTirageHybride({
    required int cagnotteId,
    required bool selectionAdminActive,
    required Map<int, int> rangsAdminSelectionnes,
    required String adminId,
    String? raisonInterne,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/tirage_api.php'),
        body: json.encode({
          'action': 'configurer_tirage_hybride',
          'cagnotte_id': cagnotteId,
          'selection_admin_active': selectionAdminActive ? 1 : 0,
          'rangs_admin': rangsAdminSelectionnes,
          'admin_id': adminId,
          'raison_interne': raisonInterne,
        }),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return {'success': false, 'message': 'Erreur serveur'};
    } catch (e) {
      return {'success': false, 'message': 'Erreur de connexion'};
    }
  }

  // Pour l'admin - démarrer le tirage hybride
  Future<Map<String, dynamic>> demarrerTirageHybride({
    required int cagnotteId,
    required String adminId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/tirage_api.php'),
        body: json.encode({
          'action': 'demarrer_tirage_hybride',
          'cagnotte_id': cagnotteId,
          'admin_id': adminId,
        }),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return {'success': false, 'message': 'Erreur serveur'};
    } catch (e) {
      return {'success': false, 'message': 'Erreur de connexion'};
    }
  }

  // Pour les users - récupérer les gagnants (affichage "aléatoire")
  Future<List<Gagnant>> getGagnantsCagnotte(int cagnotteId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/tirage_api.php'),
        body: json.encode({
          'action': 'get_gagnants',
          'cagnotte_id': cagnotteId,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return (data['gagnants'] as List)
              .map((g) => Gagnant.fromJson(g))
              .toList();
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }
}