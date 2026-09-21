import '../../core/format.dart';
import '../../core/json.dart';

/// Opérations qui portent des frais, telles que l'API les nomme.
abstract final class FeeOperations {
  static const contributionOnline = 'cotisation_en_ligne';
  static const contributionWallet = 'cotisation_solde';
  static const deposit = 'depot_portefeuille';
  static const withdrawal = 'retrait_portefeuille';
  static const transfer = 'transfert_interne';
}

/// Ce que coûte une opération précise, annoncé avant de la confirmer.
class FeeQuote {
  const FeeQuote({
    required this.operation,
    required this.label,
    required this.baseAmount,
    required this.feeAmount,
    required this.totalAmount,
    required this.netAmount,
    required this.addedToAmount,
    required this.summary,
  });

  factory FeeQuote.fromJson(Map<String, dynamic> json) => FeeQuote(
        operation: '${json['operation']}',
        label: '${json['label']}',
        baseAmount: asInt(json['base_amount']),
        feeAmount: asInt(json['fee_amount']),
        totalAmount: asInt(json['total_amount']),
        netAmount: asInt(json['net_amount']),
        addedToAmount: json['added_to_amount'] == true,
        summary: '${json['summary']}',
      );

  final String operation;
  final String label;
  final int baseAmount;
  final int feeAmount;

  /// Ce que le membre débourse réellement.
  final int totalAmount;

  /// Ce qui arrive au bénéficiaire, ou ce qui est affecté à la tontine.
  final int netAmount;
  final bool addedToAmount;

  /// Phrase toute faite, écrite par l'API : « Vous payez 5 165 FCFA : 5 000 FCFA et 165 FCFA de frais. »
  final String summary;

  bool get isFree => feeAmount == 0;
}

/// Une ligne de la grille publique des frais.
class FeeLine {
  const FeeLine({
    required this.operation,
    required this.label,
    required this.description,
    required this.rateLabel,
    required this.payerLabel,
    required this.deducted,
    required this.minAmount,
    this.maxAmount,
  });

  factory FeeLine.fromJson(Map<String, dynamic> json) => FeeLine(
        operation: '${json['operation']}',
        label: '${json['label']}',
        description: '${json['description']}',
        rateLabel: '${json['rate_label']}',
        payerLabel: '${json['payer_label']}',
        deducted: json['deducted'] == true,
        minAmount: asInt(json['min_amount']),
        maxAmount: asIntOrNull(json['max_amount']),
      );

  final String operation;
  final String label;
  final String description;
  final String rateLabel;
  final String payerLabel;

  /// Vrai quand les frais sont retenus sur la somme reçue au lieu de s'ajouter au montant payé.
  final bool deducted;
  final int minAmount;
  final int? maxAmount;

  bool get isFree => rateLabel == 'gratuit';

  /// « 3,25 % », « 3 %, au moins 100 FCFA », « 1 %, au plus 500 FCFA ».
  String get detail {
    if (isFree) return 'Gratuit';
    final parts = [rateLabel];
    if (minAmount > 0) parts.add('au moins ${fcfa(minAmount)}');
    if (maxAmount != null && maxAmount! > 0) parts.add('au plus ${fcfa(maxAmount!)}');
    return parts.join(', ');
  }
}

/// Grille complète, avec la phrase qui explique ce sur quoi les frais portent.
class FeeGrid {
  const FeeGrid({required this.lines, required this.note});

  factory FeeGrid.fromJson(Map<String, dynamic> json) => FeeGrid(
        lines: asMapList(json['operations']).map(FeeLine.fromJson).toList(),
        note: '${json['note']}',
      );

  final List<FeeLine> lines;
  final String note;
}
