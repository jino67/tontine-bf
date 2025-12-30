// services/tontine_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/tontine.dart'; // Assure-toi que le chemin est correct

class TontineService {
  static const String baseUrl = 'https://poupecosmetic.com/api/';
  static const String tontineApi = 'tontine_api.php';

  // ... (Les helpers _typeToString et _frequencyToString restent inchangés) ...
  String _typeToString(TypeTontine type) {
    switch (type) {
      case TypeTontine.tirageAuSort: return 'tirage_au_sort';
      case TypeTontine.tourDeRole: return 'tour_de_role';
      case TypeTontine.cagnotteSolidaire: return 'cagnotte_solidaire';
      case TypeTontine.epargnePersonnelle: return 'epargne_personnelle';
      case TypeTontine.epargneGroupe: return 'epargne_groupe';
    }
  }

  String _frequencyToString(Frequency freq) {
    switch (freq) {
      case Frequency.quotidien: return 'quotidien';
      case Frequency.hebdomadaire: return 'hebdomadaire';
      case Frequency.mensuel: return 'mensuel';
    }
  }


  // Créer une nouvelle tontine
  Future<Map<String, dynamic>> createTontine({
    required int creatorId,
    required String nom,
    required TypeTontine type,
    required double montant,
    required Frequency frequence,
    required int duree,
    int maxParticipants = 1,
    String? objectif,
    String? codeInvitation,
    List<int>? invitedUserIds, // <-- ✅ NOUVEAU PARAMÈTRE AJOUTÉ
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl$tontineApi'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'action': 'create_tontine',
          'creator_id': creatorId,
          'nom': nom,
          'type': _typeToString(type),
          'montant_cotisation': montant,
          'frequence': _frequencyToString(frequence),
          'duree': duree,
          'max_participants': maxParticipants,
          'objectif': objectif,
          'code_invitation': codeInvitation,
          'invited_user_ids': invitedUserIds ?? [], // <-- ✅ NOUVELLE DONNÉE ENVOYÉE
        }),
      );

      print('Create tontine response: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return {
            'success': true,
            'message': data['message'],
            'tontine_id': data['tontine_id'],
            'code_invitation': data['code_invitation'],
          };
        } else {
          throw Exception(data['message']);
        }
      } else {
        throw Exception('Erreur serveur: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Erreur de création: $e');
    }
  }

  // ... (Le reste de tes fonctions : joinTontine, getSystemTontines, etc. restent inchangées) ...
  // ...
  // Rejoindre une tontine avec code d'invitation
  Future<Map<String, dynamic>> joinTontine({
    required int userId,
    required String codeInvitation,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl$tontineApi'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'action': 'join_tontine',
          'user_id': userId,
          'code_invitation': codeInvitation,
        }),
      );

      // print('Join tontine response: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': data['success'],
          'message': data['message'],
        };
      } else {
        throw Exception('Erreur serveur: ${response.statusCode}');
      }
    } catch (e) {
      // print('Join tontine error: $e');
      throw Exception('Erreur de participation: $e');
    }
  }

  // Obtenir les tontines système (configurées par l'admin)
  Future<List<Tontine>> getSystemTontines() async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl$tontineApi'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'action': 'get_system_tontines',
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          List<Tontine> tontines = [];
          // Assurez-vous que le modèle Tontine est capable de gérer les types du PHP
          for (var tontineData in data['tontines']) {
            tontines.add(Tontine.fromJson(tontineData));
          }
          return tontines;
        } else {
          throw Exception(data['message']);
        }
      } else {
        throw Exception('Erreur serveur: ${response.statusCode}');
      }
    } catch (e) {
      // print('Get system tontines error: $e');
      return []; // Retourne liste vide en cas d'erreur
    }
  }

  // Obtenir les participants d'une tontine
  Future<List<Map<String, dynamic>>> getTontineParticipants(String tontineId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl$tontineApi'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'action': 'get_participants',
          'tontine_id': tontineId,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return (data['participants'] as List).cast<Map<String, dynamic>>();
        } else {
          throw Exception(data['message']);
        }
      } else {
        throw Exception('Erreur serveur: ${response.statusCode}');
      }
    } catch (e) {
      // print('Get participants error: $e');
      throw Exception('Erreur de chargement des participants: $e');
    }
  }

  // Générer un nouveau code d'invitation
  Future<Map<String, dynamic>> generateInvitationCode(String tontineId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl$tontineApi'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'action': 'generate_invitation',
          'tontine_id': tontineId,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': data['success'],
          'code_invitation': data['code_invitation'],
          'message': data['message'],
        };
      } else {
        throw Exception('Erreur serveur: ${response.statusCode}');
      }
    } catch (e) {
      // print('Generate invitation error: $e');
      throw Exception('Erreur de génération: $e');
    }
  }

  // Rechercher des utilisateurs par numéro de téléphone
  Future<List<Map<String, dynamic>>> searchUsers(String phoneQuery) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl$tontineApi'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'action': 'search_users',
          'phone_query': phoneQuery,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return (data['users'] as List).cast<Map<String, dynamic>>();
        } else {
          throw Exception(data['message']);
        }
      } else {
        throw Exception('Erreur serveur: ${response.statusCode}');
      }
    } catch (e) {
      // print('Search users error: $e');
      throw Exception('Erreur de recherche: $e');
    }
  }
}