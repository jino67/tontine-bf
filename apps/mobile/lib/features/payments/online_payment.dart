import '../../core/api/api_client.dart';
import '../../core/json.dart';

enum OnlinePaymentStatus {
  pending('en_attente'),
  paid('payee'),
  cancelled('annulee'),
  failed('echouee');

  const OnlinePaymentStatus(this.apiValue);

  final String apiValue;

  static OnlinePaymentStatus fromApi(Object? value) =>
      values.firstWhere((status) => status.apiValue == value, orElse: () => pending);
}

/// Paiement en ligne par PayDunya, tel que renvoyé par l'API.
class OnlinePayment {
  const OnlinePayment({
    required this.id,
    required this.amount,
    required this.status,
    this.checkoutUrl,
    this.receiptUrl,
    this.failureReason,
    this.applied = false,
  });

  factory OnlinePayment.fromJson(Map<String, dynamic> json) => OnlinePayment(
        id: asInt(json['id']),
        amount: asInt(json['amount']),
        status: OnlinePaymentStatus.fromApi(json['status']),
        checkoutUrl: asStringOrNull(json['checkout_url']),
        receiptUrl: asStringOrNull(json['receipt_url']),
        failureReason: asStringOrNull(json['failure_reason']),
        applied: json['applied'] == true,
      );

  final int id;
  final int amount;
  final OnlinePaymentStatus status;
  final String? checkoutUrl;
  final String? receiptUrl;
  final String? failureReason;

  /// Faux si PayDunya a reçu l'argent mais que l'API n'a pas pu l'affecter (le trésorier régularise).
  final bool applied;

  bool get isPending => status == OnlinePaymentStatus.pending;
}

class PaymentRepository {
  PaymentRepository(this._api, [this.organizationId]);

  final ApiClient _api;

  /// Nul pour un dépôt sur le portefeuille, qui n'appartient à aucune organisation.
  final int? organizationId;

  String get _base => '/orgs/$organizationId';

  Future<OnlinePayment> payContribution(int tontineId, int cycleId, int contributionId) async => OnlinePayment.fromJson(
        asMap(unwrap(await _api.post('$_base/tontines/$tontineId/cycles/$cycleId/contributions/$contributionId/pay'))),
      );

  Future<OnlinePayment> payCagnotte(int cagnotteId, int amount) async =>
      OnlinePayment.fromJson(asMap(unwrap(await _api.post('$_base/cagnottes/$cagnotteId/pay', {'amount': amount}))));

  /// Cagnotte ouverte à tous : on y participe sans appartenir à l'organisation qui la porte.
  Future<OnlinePayment> payPublicCagnotte(int cagnotteId, int amount) async => OnlinePayment.fromJson(
        asMap(unwrap(await _api.post('/cagnottes/$cagnotteId/pay', {'amount': amount}))),
      );

  Future<void> payPublicCagnotteWithBalance(int cagnotteId, int amount) =>
      _api.post('/cagnottes/$cagnotteId/pay-with-balance', {'amount': amount});

  /// Réglé avec l'argent déjà présent sur le solde : rien ne sort de l'application.
  Future<void> payContributionWithBalance(int tontineId, int cycleId, int contributionId) =>
      _api.post('$_base/tontines/$tontineId/cycles/$cycleId/contributions/$contributionId/pay-with-balance');

  Future<void> payCagnotteWithBalance(int cagnotteId, int amount) =>
      _api.post('$_base/cagnottes/$cagnotteId/pay-with-balance', {'amount': amount});

  /// Relit le statut : l'API interroge PayDunya si le paiement est encore en attente.
  /// La route personnelle répond pour tous les paiements lancés par le membre connecté.
  Future<OnlinePayment> status(int paymentId) async =>
      OnlinePayment.fromJson(asMap(unwrap(await _api.get('/payments/$paymentId'))));
}
