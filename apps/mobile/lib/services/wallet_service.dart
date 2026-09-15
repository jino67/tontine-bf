import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/wallet.dart';

class WalletService {
  static const String baseUrl = 'https://poupecosmetic.com/api';

  // Obtenir le portefeuille de l'utilisateur
  Future<Wallet> getWallet(String userId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/wallet_api.php'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'action': 'get_wallet',
          'user_id': userId,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return Wallet.fromJson(data['wallet']);
        } else {
          throw Exception(data['message']);
        }
      } else {
        throw Exception('Erreur serveur: ${response.statusCode}');
      }
    } catch (e) {
      print('Get wallet error: $e');
      throw Exception('Erreur de chargement du portefeuille: $e');
    }
  }

  // Déposer de l'argent (simulation Orange Money)
  Future<Map<String, dynamic>> deposit({
    required String userId,
    required double amount,
    required String phoneNumber,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/wallet_api.php'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'action': 'deposit',
          'user_id': userId,
          'amount': amount,
          'phone_number': phoneNumber,
        }),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Erreur serveur: ${response.statusCode}');
      }
    } catch (e) {
      print('Deposit error: $e');
      throw Exception('Erreur de dépôt: $e');
    }
  }

  // Retirer de l'argent
  Future<Map<String, dynamic>> withdraw({
    required String userId,
    required double amount,
    required String phoneNumber,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/wallet_api.php'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'action': 'withdraw',
          'user_id': userId,
          'amount': amount,
          'phone_number': phoneNumber,
        }),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Erreur serveur: ${response.statusCode}');
      }
    } catch (e) {
      print('Withdraw error: $e');
      throw Exception('Erreur de retrait: $e');
    }
  }

  // Obtenir l'historique des transactions
  Future<List<Transaction>> getTransactionHistory(String walletId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/wallet_api.php'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'action': 'get_transactions',
          'wallet_id': walletId,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          List<Transaction> transactions = [];
          for (var transactionData in data['transactions']) {
            transactions.add(Transaction.fromJson(transactionData));
          }
          return transactions;
        } else {
          throw Exception(data['message']);
        }
      } else {
        throw Exception('Erreur serveur: ${response.statusCode}');
      }
    } catch (e) {
      print('Get transactions error: $e');
      throw Exception('Erreur de chargement des transactions: $e');
    }
  }
}