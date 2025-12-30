// lib/features/cagnotte/services/groupe_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/groupe_model.dart';
import '../models/groupe_model.dart';

class GroupeService {
  static const String baseUrl = 'https://poupecosmetic.com/api';

  // Récupérer les groupes d'un utilisateur
  Future<List<GroupeDiscussion>> getGroupesUtilisateur(String userId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/groupe_api.php'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'action': 'get_groupes_utilisateur',
          'user_id': userId,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          List<GroupeDiscussion> groupes = [];
          for (var groupeData in data['groupes']) {
            groupes.add(GroupeDiscussion.fromJson(groupeData));
          }
          return groupes;
        }
      }
      return [];
    } catch (e) {
      print('Erreur getGroupesUtilisateur: $e');
      return [];
    }
  }

  // Récupérer les messages d'un groupe
  Future<List<MessageGroupe>> getMessagesGroupe(int groupeId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/groupe_api.php'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'action': 'get_messages_groupe',
          'groupe_id': groupeId,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          List<MessageGroupe> messages = [];
          for (var messageData in data['messages']) {
            messages.add(MessageGroupe.fromJson(messageData));
          }
          return messages;
        }
      }
      return [];
    } catch (e) {
      print('Erreur getMessagesGroupe: $e');
      return [];
    }
  }

  // Envoyer un message dans un groupe
  Future<Map<String, dynamic>> envoyerMessage({
    required int groupeId,
    required String userId,
    required String message,
    required String type,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/groupe_api.php'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'action': 'envoyer_message',
          'groupe_id': groupeId,
          'user_id': userId,
          'message': message,
          'type': type,
        }),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return {'success': false, 'message': 'Erreur serveur'};
    } catch (e) {
      print('Erreur envoyerMessage: $e');
      return {'success': false, 'message': 'Erreur de connexion'};
    }
  }

  // Rejoindre un groupe
  Future<Map<String, dynamic>> rejoindreGroupe({
    required int groupeId,
    required String userId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/groupe_api.php'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'action': 'rejoindre_groupe',
          'groupe_id': groupeId,
          'user_id': userId,
        }),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return {'success': false, 'message': 'Erreur serveur'};
    } catch (e) {
      print('Erreur rejoindreGroupe: $e');
      return {'success': false, 'message': 'Erreur de connexion'};
    }
  }
}