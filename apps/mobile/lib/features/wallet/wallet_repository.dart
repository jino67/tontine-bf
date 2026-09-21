import 'package:flutter/foundation.dart';

import '../../core/api/api_client.dart';
import '../../core/json.dart';
import '../payments/online_payment.dart';
import 'wallet.dart';

/// Portefeuille d'un membre : solde, historique, transferts, dépôt et retrait.
class WalletRepository {
  WalletRepository(this._api);

  final ApiClient _api;

  /// Monte d'un cran à chaque mouvement : les écrans qui l'écoutent se rafraîchissent.
  final revision = ValueNotifier<int>(0);

  Future<WalletSummary> summary() async => WalletSummary.fromJson(asMap(unwrap(await _api.get('/wallet'))));

  Future<List<WalletMovement>> movements() async =>
      asMapList(unwrap(await _api.get('/wallet/transactions'))).map(WalletMovement.fromJson).toList();

  Future<WalletMovement> transfer({required String phone, required int amount, String? note}) async {
    final movement = WalletMovement.fromJson(
      asMap(unwrap(await _api.post('/wallet/transfer', {'phone': phone, 'amount': amount, 'note': ?note}))),
    );
    revision.value++;

    return movement;
  }

  Future<WalletMovement> withdraw(int amount) async {
    final movement = WalletMovement.fromJson(asMap(unwrap(await _api.post('/wallet/withdraw', {'amount': amount}))));
    revision.value++;

    return movement;
  }

  /// Dépôt par mobile money : l'API crée un paiement PayDunya comme pour une cotisation.
  Future<OnlinePayment> deposit(int amount) async =>
      OnlinePayment.fromJson(asMap(unwrap(await _api.post('/wallet/deposit', {'amount': amount}))));

  /// Sans code, l'API en envoie un et répond 202. Avec le code, le numéro est enregistré.
  Future<bool> savePayoutPhone({required String phone, required String mode, String? code}) async {
    final body = asMap(await _api.put('/wallet/payout-phone', {
      'phone': phone,
      'withdraw_mode': mode,
      'code': ?code,
    }));

    final saved = body.containsKey('data');
    if (saved) revision.value++;

    return saved;
  }
}
