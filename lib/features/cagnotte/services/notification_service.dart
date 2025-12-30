// lib/features/cagnotte/services/notification_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/notification_model.dart';

class NotificationService {
  static const String baseUrl = 'https://poupecosmetic.com/api';

  // Récupérer les notifications d'un utilisateur
  Future<List<Notification>> getNotifications(String userId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/notification_api.php'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'action': 'get_notifications',
          'user_id': userId,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          List<Notification> notifications = [];
          for (var notifData in data['notifications']) {
            notifications.add(Notification.fromJson(notifData));
          }
          return notifications;
        }
      }
      return [];
    } catch (e) {
      print('Erreur getNotifications: $e');
      return [];
    }
  }

  // Marquer une notification comme lue
  Future<Map<String, dynamic>> marquerCommeLue({
    required String notificationId,
    required String userId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/notification_api.php'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'action': 'marquer_comme_lue',
          'notification_id': notificationId,
          'user_id': userId,
        }),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return {'success': false, 'message': 'Erreur serveur'};
    } catch (e) {
      print('Erreur marquerCommeLue: $e');
      return {'success': false, 'message': 'Erreur de connexion'};
    }
  }

  // Marquer toutes les notifications comme lues
  Future<Map<String, dynamic>> marquerToutesLues(String userId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/notification_api.php'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'action': 'marquer_toutes_lues',
          'user_id': userId,
        }),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return {'success': false, 'message': 'Erreur serveur'};
    } catch (e) {
      print('Erreur marquerToutesLues: $e');
      return {'success': false, 'message': 'Erreur de connexion'};
    }
  }

  // Supprimer une notification
  Future<Map<String, dynamic>> supprimerNotification({
    required String notificationId,
    required String userId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/notification_api.php'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'action': 'supprimer_notification',
          'notification_id': notificationId,
          'user_id': userId,
        }),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return {'success': false, 'message': 'Erreur serveur'};
    } catch (e) {
      print('Erreur supprimerNotification: $e');
      return {'success': false, 'message': 'Erreur de connexion'};
    }
  }
}