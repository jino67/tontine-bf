import 'package:app_tontine_bf/features/fees/fees.dart';
import 'package:app_tontine_bf/features/notifications/notifications.dart';
import 'package:app_tontine_bf/features/tontines/models.dart';
import 'package:app_tontine_bf/features/wallet/wallet.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('lit un solde et ce que le niveau permet', () {
    final summary = WalletSummary.fromJson({
      'balance': 12500,
      'level': 0,
      'max_balance': 100000,
      'daily_withdrawal': 50000,
      'deposits_enabled': false,
      'min_deposit': 500,
      'min_withdrawal': 1000,
      'payout_phone': null,
      'payout_mode': null,
    });

    expect(summary.balance, 12500);
    expect(summary.depositsEnabled, isFalse);
    // Sans numéro enregistré, le retrait n'est pas proposé.
    expect(summary.canWithdraw, isFalse);
  });

  test('distingue ce qui entre de ce qui sort du solde', () {
    final received = WalletMovement.fromJson({
      'id': 1,
      'type': 'gain',
      'label': 'Gain reçu',
      'status': 'reussie',
      'direction': 'credit',
      'amount': 19000,
      'fee_amount': 0,
      'signed_amount': 19000,
      'balance_after': 19000,
    });
    final withdrawal = WalletMovement.fromJson({
      'id': 2,
      'type': 'retrait',
      'label': 'Retrait',
      'status': 'en_attente',
      'direction': 'debit',
      'amount': 10000,
      'fee_amount': 250,
      'signed_amount': -10000,
      'balance_after': 8750,
    });

    expect(received.isCredit, isTrue);
    expect(withdrawal.isCredit, isFalse);
    expect(withdrawal.isPending, isTrue);
    expect(withdrawal.feeAmount, 250);
  });

  test('reprend la phrase de frais écrite par l’API', () {
    final quote = FeeQuote.fromJson({
      'operation': 'cotisation_en_ligne',
      'label': 'Cotisation payée en ligne',
      'base_amount': 5000,
      'fee_amount': 165,
      'total_amount': 5165,
      'net_amount': 5000,
      'added_to_amount': true,
      'summary': 'Vous payez 5 165 FCFA : 5 000 FCFA et 165 FCFA de frais de service.',
    });

    expect(quote.totalAmount, 5165);
    expect(quote.isFree, isFalse);
    expect(quote.summary, contains('165 FCFA'));
  });

  test('écrit une ligne de grille lisible, minimum et plafond compris', () {
    final deposit = FeeLine.fromJson({
      'operation': 'depot_portefeuille',
      'label': 'Dépôt sur le portefeuille',
      'description': 'Argent versé sur votre solde.',
      'rate_label': '3 %',
      'payer_label': 'le payeur',
      'deducted': false,
      'min_amount': 100,
      'max_amount': null,
    });
    final free = FeeLine.fromJson({
      'operation': 'transfert_interne',
      'label': 'Transfert entre membres',
      'description': 'Gratuit.',
      'rate_label': 'gratuit',
      'payer_label': 'la plateforme',
      'deducted': true,
      'min_amount': 0,
      'max_amount': 0,
    });

    expect(deposit.detail, '3 %, au moins 100 FCFA');
    expect(free.isFree, isTrue);
    expect(free.detail, 'Gratuit');
  });

  test('ne propose jamais un moyen en ligne à la saisie du trésorier', () {
    expect(PaymentMethod.fromApi('portefeuille'), PaymentMethod.wallet);
    expect(PaymentMethod.manual, isNot(contains(PaymentMethod.wallet)));
    expect(PaymentMethod.manual, isNot(contains(PaymentMethod.paydunya)));
    expect(PaymentMethod.manual, contains(PaymentMethod.cash));
  });

  test('lit un message et les relances coupées', () {
    final message = AppNotification.fromJson({
      'id': 7,
      'type': 'rappel_jour',
      'label': 'Rappel le jour de l’échéance',
      'title': 'C’est aujourd’hui',
      'body': '5 000 FCFA pour le tour 1.',
      'channel': 'application',
      'read': false,
      'related': {'kind': 'tontine', 'id': 12},
    });
    final settings = NotificationSettings.fromJson({
      'reminders': true,
      'mail': true,
      'push': false,
      'whatsapp': true,
      'sms': false,
      'muted': ['tontine:12'],
    });

    expect(message.isReminder, isTrue);
    expect(message.relatedKind, 'tontine');
    expect(settings.mutes('tontine', 12), isTrue);
    expect(settings.mutes('tontine', 13), isFalse);
    expect(settings.push, isFalse);
  });
}
