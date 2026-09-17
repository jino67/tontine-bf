import 'package:app_tontine_bf/features/cagnottes/cagnotte.dart';
import 'package:app_tontine_bf/features/payments/online_payment.dart';
import 'package:app_tontine_bf/features/tontines/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('lit un paiement en ligne tel que renvoyé par l’API', () {
    final pending = OnlinePayment.fromJson({
      'id': 12,
      'purpose': 'cotisation',
      'amount': 5000,
      'status': 'en_attente',
      'checkout_url': 'https://paydunya.com/sandbox-checkout/invoice/test_abc',
      'applied': false,
    });
    final paid = OnlinePayment.fromJson({'id': 12, 'amount': 5000, 'status': 'payee', 'checkout_url': null, 'applied': true});

    expect(pending.isPending, isTrue);
    expect(pending.checkoutUrl, 'https://paydunya.com/sandbox-checkout/invoice/test_abc');
    expect(paid.status, OnlinePaymentStatus.paid);
    expect(paid.applied, isTrue);
    expect(paid.checkoutUrl, isNull);
  });

  test('ne propose jamais PayDunya comme moyen saisi à la main', () {
    expect(PaymentMethod.fromApi('paydunya'), PaymentMethod.paydunya);
    expect(PaymentMethod.manual, isNot(contains(PaymentMethod.paydunya)));
    expect(PaymentMethod.manual, contains(PaymentMethod.orangeMoney));
  });

  test('lit l’envoi PayDunya en cours d’un gain', () {
    final winner = CagnotteWinner.fromJson({
      'id': 3,
      'rank': 1,
      'prize_amount': 1575,
      'paid_at': null,
      'payout': {'status': 'en_cours', 'withdraw_mode': 'orange-money-burkina', 'amount': 1575, 'failure_reason': null},
    });

    expect(winner.payout?.isProcessing, isTrue);
    expect(winner.payout?.amount, 1575);
  });
}
