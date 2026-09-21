import '../../core/json.dart';

/// Solde d'un membre et ce que son niveau lui permet.
class WalletSummary {
  const WalletSummary({
    required this.balance,
    required this.level,
    required this.maxBalance,
    required this.dailyWithdrawal,
    required this.depositsEnabled,
    required this.minDeposit,
    required this.minWithdrawal,
    this.payoutPhone,
    this.payoutMode,
  });

  factory WalletSummary.fromJson(Map<String, dynamic> json) => WalletSummary(
        balance: asInt(json['balance']),
        level: asInt(json['level']),
        maxBalance: asInt(json['max_balance']),
        dailyWithdrawal: asInt(json['daily_withdrawal']),
        depositsEnabled: json['deposits_enabled'] == true,
        minDeposit: asInt(json['min_deposit']),
        minWithdrawal: asInt(json['min_withdrawal']),
        payoutPhone: asStringOrNull(json['payout_phone']),
        payoutMode: asStringOrNull(json['payout_mode']),
      );

  final int balance;

  /// 0 compte neuf, 1 confirmé, 2 pièce d'identité vérifiée.
  final int level;
  final int maxBalance;
  final int dailyWithdrawal;
  final bool depositsEnabled;
  final int minDeposit;
  final int minWithdrawal;
  final String? payoutPhone;
  final String? payoutMode;

  bool get canWithdraw => payoutPhone != null && payoutMode != null;
}

enum WalletMovementStatus {
  pending('en_attente'),
  succeeded('reussie'),
  failed('echouee');

  const WalletMovementStatus(this.apiValue);

  final String apiValue;

  static WalletMovementStatus fromApi(Object? value) =>
      values.firstWhere((status) => status.apiValue == value, orElse: () => succeeded);
}

/// Une ligne de l'historique du portefeuille.
class WalletMovement {
  const WalletMovement({
    required this.id,
    required this.type,
    required this.label,
    required this.status,
    required this.amount,
    required this.feeAmount,
    required this.signedAmount,
    this.balanceAfter,
    this.description,
    this.failureReason,
    this.createdAt,
  });

  factory WalletMovement.fromJson(Map<String, dynamic> json) => WalletMovement(
        id: asInt(json['id']),
        type: '${json['type']}',
        label: '${json['label']}',
        status: WalletMovementStatus.fromApi(json['status']),
        amount: asInt(json['amount']),
        feeAmount: asInt(json['fee_amount']),
        signedAmount: asInt(json['signed_amount']),
        balanceAfter: asIntOrNull(json['balance_after']),
        description: asStringOrNull(json['description']),
        failureReason: asStringOrNull(json['failure_reason']),
        createdAt: asDate(json['created_at']),
      );

  final int id;
  final String type;
  final String label;
  final WalletMovementStatus status;
  final int amount;
  final int feeAmount;

  /// Négatif quand l'argent sort du solde.
  final int signedAmount;
  final int? balanceAfter;
  final String? description;
  final String? failureReason;
  final DateTime? createdAt;

  bool get isCredit => signedAmount >= 0;

  bool get isPending => status == WalletMovementStatus.pending;

  bool get hasFailed => status == WalletMovementStatus.failed;
}

/// Opérateurs mobile money acceptés pour un retrait, tels que l'API les nomme.
const withdrawModes = <String, String>{
  'orange-money-burkina': 'Orange Money Burkina',
  'moov-burkina-faso': 'Moov Money Burkina',
};
