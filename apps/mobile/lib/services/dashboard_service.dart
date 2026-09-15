import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/tontine.dart';
import '../models/wallet.dart';

class DashboardService {
  static const String baseUrl = 'https://poupecosmetic.com/api';

  Future<Map<String, dynamic>> getDashboardStats(String userId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/dashboard_api.php'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'action': 'get_dashboard_stats',
          'user_id': userId,
        }),
      );

      // print('Dashboard stats response: ${response.statusCode}'); // Supprimé: avoid_print
      // print('Dashboard stats body: ${response.body}'); // Supprimé: avoid_print

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body) as Map<String, dynamic>;
        if (data['success'] == true) {
          final stats = data['stats'] as Map<String, dynamic>?;
          return stats ?? _getDefaultStats();
        } else {
          // print('Dashboard API error: ${data['message']}'); // Supprimé: avoid_print
          return _getDefaultStats();
        }
      } else {
        // print('Dashboard server error: ${response.statusCode}'); // Supprimé: avoid_print
        return _getDefaultStats();
      }
    } catch (e) {
      // print('Get dashboard stats error: $e'); // Supprimé: avoid_print
      return _getDefaultStats();
    }
  }

  Future<List<Tontine>> getUserTontines(String userId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/tontine_api.php'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'action': 'get_user_tontines',
          'user_id': userId,
        }),
      );

      // print('User tontines response: ${response.statusCode}'); // Supprimé: avoid_print
      // print('User tontines body: ${response.body}'); // Supprimé: avoid_print

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body) as Map<String, dynamic>;
        if (data['success'] == true) {
          final List<dynamic> tontinesData = data['tontines'] as List<dynamic>? ?? [];
          List<Tontine> tontines = [];
          for (var tontineData in tontinesData) {
            try {
              tontines.add(Tontine.fromJson(tontineData as Map<String, dynamic>));
            } catch (e) {
              // print('Error parsing tontine: $e'); // Supprimé: avoid_print
            }
          }
          return tontines;
        } else {
          // print('User tontines API error: ${data['message']}'); // Supprimé: avoid_print
          return [];
        }
      } else {
        // print('User tontines server error: ${response.statusCode}'); // Supprimé: avoid_print
        return [];
      }
    } catch (e) {
      // print('Get user tontines error: $e'); // Supprimé: avoid_print
      return [];
    }
  }

  Future<Wallet?> getUserWallet(String userId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/wallet_api.php'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'action': 'get_wallet',
          'user_id': userId,
        }),
      );

      // print('User wallet response: ${response.statusCode}'); // Supprimé: avoid_print
      // print('User wallet body: ${response.body}'); // Supprimé: avoid_print

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body) as Map<String, dynamic>;
        if (data['success'] == true) {
          return Wallet.fromJson(data['wallet'] as Map<String, dynamic>);
        } else {
          // print('User wallet API error: ${data['message']}'); // Supprimé: avoid_print
          return null;
        }
      } else {
        // print('User wallet server error: ${response.statusCode}'); // Supprimé: avoid_print
        return null;
      }
    } catch (e) {
      // print('Get user wallet error: $e'); // Supprimé: avoid_print
      return null;
    }
  }

  Future<Map<String, dynamic>> getDetailedStats(String userId) async {
    try {
      final results = await Future.wait([
        getDashboardStats(userId),
        getUserTontines(userId),
        getUserWallet(userId),
      ]);

      // Les types sont castés ici pour satisfaire l'analyseur suite à Future.wait
      final Map<String, dynamic> stats = results[0] as Map<String, dynamic>;
      final List<Tontine> tontines = results[1] as List<Tontine>;
      final Wallet? wallet = results[2] as Wallet?;

      double totalMontantTontines = 0;
      int tontinesActives = 0;
      int tontinesTerminees = 0;
      double totalCotisationsMensuelles = 0;

      for (var tontine in tontines) {
        totalMontantTontines += tontine.montantCotisation;

        if (tontine.isActive) {
          tontinesActives++;
          switch (tontine.frequence) {
            case Frequency.quotidien:
              totalCotisationsMensuelles += tontine.montantCotisation * 30;
              break;
            case Frequency.hebdomadaire:
              totalCotisationsMensuelles += tontine.montantCotisation * 4;
              break;
            case Frequency.mensuel:
              totalCotisationsMensuelles += tontine.montantCotisation;
              break;
          }
        } else if (tontine.isCompleted) {
          tontinesTerminees++;
        }
      }

      return {
        ...stats,
        'wallet_balance': wallet?.balance ?? 0,
        'total_montant_tontines': totalMontantTontines,
        'tontines_actives_count': tontinesActives,
        'tontines_terminees_count': tontinesTerminees,
        'total_cotisations_mensuelles': totalCotisationsMensuelles,
        'total_tontines_count': tontines.length,
        'prochain_paiement': _calculateNextPayment(tontines),
      };
    } catch (e) {
      // print('Get detailed stats error: $e'); // Supprimé: avoid_print
      return _getDefaultStats();
    }
  }

  DateTime? _calculateNextPayment(List<Tontine> tontines) {
    final now = DateTime.now();
    DateTime? nextPayment;

    for (var tontine in tontines) {
      if (tontine.isActive) {
        DateTime paymentDate;

        switch (tontine.frequence) {
          case Frequency.quotidien:
            paymentDate = now.add(const Duration(days: 1));
            break;
          case Frequency.hebdomadaire:
            paymentDate = now.add(const Duration(days: 7));
            break;
          case Frequency.mensuel:
          // Tentative d'aller au mois suivant
            paymentDate = DateTime(now.year, now.month + 1, now.day);
            break;
        // Le default n'était pas un cas de Tontine Frequency, il a été retiré ou renommé 'mensuel'
        // Laissez le case mensuel servir de fall-through si Frequency n'est pas bien géré.
          default:
            paymentDate = now.add(const Duration(days: 30));
        }

        if (nextPayment == null || paymentDate.isBefore(nextPayment)) {
          nextPayment = paymentDate;
        }
      }
    }

    return nextPayment;
  }

  Map<String, dynamic> _getDefaultStats() {
    return {
      'balance': 0.0,
      'active_tontines': 0,
      'completed_tontines': 0,
      'monthly_contributions': 0.0,
      'total_tontines': 0,
      'wallet_balance': 0.0,
      'total_montant_tontines': 0.0,
      'tontines_actives_count': 0,
      'tontines_terminees_count': 0,
      'total_cotisations_mensuelles': 0.0,
      'total_tontines_count': 0,
      'prochain_paiement': null,
    };
  }

  Future<bool> checkApiConnection() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/test_api.php'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body) as Map<String, dynamic>;
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      // print('API connection check error: $e'); // Supprimé: avoid_print
      return false;
    }
  }

  Future<List<Tontine>> getRecentTontines(String userId, {int limit = 5}) async {
    try {
      final List<Tontine> tontines = await getUserTontines(userId);
      tontines.sort((a, b) => b.dateCreation.compareTo(a.dateCreation));
      return tontines.take(limit).toList();
    } catch (e) {
      // print('Get recent tontines error: $e'); // Supprimé: avoid_print
      return [];
    }
  }

  Future<List<Tontine>> getActiveTontines(String userId) async {
    try {
      final List<Tontine> tontines = await getUserTontines(userId);
      return tontines.where((tontine) => tontine.isActive).toList();
    } catch (e) {
      // print('Get active tontines error: $e'); // Supprimé: avoid_print
      return [];
    }
  }

  Future<List<Tontine>> getPendingTontines(String userId) async {
    try {
      final List<Tontine> tontines = await getUserTontines(userId);
      return tontines.where((tontine) => tontine.isPending).toList();
    } catch (e) {
      // print('Get pending tontines error: $e'); // Supprimé: avoid_print
      return [];
    }
  }

  Future<Map<String, dynamic>> getFinancialSummary(String userId) async {
    try {
      final results = await Future.wait([
        getDashboardStats(userId),
        getUserTontines(userId),
        getUserWallet(userId),
      ]);

      // Les types sont castés ici pour satisfaire l'analyseur suite à Future.wait
      final List<Tontine> tontines = results[1] as List<Tontine>;
      final Wallet? wallet = results[2] as Wallet?;

      double totalInvesti = 0;
      double totalRecu = 0;
      // double totalAttendu est décomenté pour l'usage dans la logique
      double totalAttendu = 0;

      for (var tontine in tontines) {
        if (tontine.isCompleted) {
          totalInvesti += tontine.montantCotisation * tontine.duree;
          totalRecu += tontine.montantActuel;
        } else if (tontine.isActive) {
          // Logique légèrement modifiée pour mieux refléter l'investissement/attendu
          // totalInvesti += tontine.montantCotisation * tontine.participants.length; // Logic bug potential fix: Assuming totalInvesti means *already* invested
          totalAttendu += tontine.montantCotisation * tontine.duree;
        }
      }

      return {
        'solde_actuel': wallet?.balance ?? 0,
        'total_investi': totalInvesti,
        'total_recu': totalRecu,
        'total_attendu': totalAttendu,
        'benefice_net': totalRecu - totalInvesti,
        'rendement': totalInvesti > 0 ? ((totalRecu - totalInvesti) / totalInvesti) * 100 : 0,
      };
    } catch (e) {
      // print('Get financial summary error: $e'); // Supprimé: avoid_print
      return {
        'solde_actuel': 0.0,
        'total_investi': 0.0,
        'total_recu': 0.0,
        'total_attendu': 0.0,
        'benefice_net': 0.0,
        'rendement': 0.0,
      };
    }
  }
}