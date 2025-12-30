import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/cagnotte_model.dart';
import '../models/participation_model.dart';

class CagnotteService {
  static const String baseUrl = 'https://poupecosmetic.com/api';

  Future<List<Cagnotte>> getCagnottesList(String userId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/cagnotte_api.php'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'action': 'get_cagnottes',
          'user_id': userId,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          // Utilisation de cast<Map<String, dynamic>> pour un typage plus strict
          final List<dynamic> cagnottesData = data['cagnottes'] as List<dynamic>;
          List<Cagnotte> cagnottes = [];
          for (var cagnotteData in cagnottesData) {
            cagnottes.add(Cagnotte.fromJson(cagnotteData as Map<String, dynamic>));
          }
          return cagnottes;
        } else {
          throw Exception(data['message'] ?? 'Erreur inconnue');
        }
      } else {
        throw Exception('Erreur serveur: ${response.statusCode}');
      }
    } catch (e) {
      // print('Erreur getCagnottesList: $e'); // Supprimé: avoid_print
      rethrow;
    }
  }

  Future<Cagnotte> getCagnotteDetail(String userId, int cagnotteId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/cagnotte_api.php'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'action': 'get_cagnotte_detail',
          'user_id': userId,
          'cagnotte_id': cagnotteId,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return Cagnotte.fromJson(data['cagnotte'] as Map<String, dynamic>);
        } else {
          throw Exception(data['message'] ?? 'Erreur inconnue');
        }
      } else {
        throw Exception('Erreur serveur: ${response.statusCode}');
      }
    } catch (e) {
      // print('Erreur getCagnotteDetail: $e'); // Supprimé: avoid_print
      rethrow;
    }
  }

  Future<Map<String, dynamic>> participerCagnotte({
    required String userId,
    required int cagnotteId,
    required double montant,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/cagnotte_api.php'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'action': 'participer_cagnotte',
          'user_id': userId,
          'cagnotte_id': cagnotteId,
          'montant': montant,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return {
            'success': true,
            'message': data['message'],
            'tickets_gagnes': data['tickets_gagnes'],
            'nouveau_solde': data['nouveau_solde'],
          };
        } else {
          return {
            'success': false,
            'message': data['message'] ?? 'Erreur inconnue',
          };
        }
      } else {
        return {
          'success': false,
          'message': 'Erreur serveur: ${response.statusCode}',
        };
      }
    } catch (e) {
      // print('Erreur participerCagnotte: $e'); // Supprimé: avoid_print
      return {
        'success': false,
        'message': 'Erreur de connexion',
      };
    }
  }

  Future<List<Participation>> getMesParticipations(String userId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/cagnotte_api.php'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'action': 'get_mes_participations',
          'user_id': userId,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final List<dynamic> participationsData = data['participations'] as List<dynamic>;
          List<Participation> participations = [];
          for (var partData in participationsData) {
            participations.add(Participation.fromJson(partData as Map<String, dynamic>));
          }
          return participations;
        } else {
          throw Exception(data['message'] ?? 'Erreur inconnue');
        }
      } else {
        throw Exception('Erreur serveur: ${response.statusCode}');
      }
    } catch (e) {
      // print('Erreur getMesParticipations: $e'); // Supprimé: avoid_print
      rethrow;
    }
  }
}