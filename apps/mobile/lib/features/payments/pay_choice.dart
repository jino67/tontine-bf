import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/format.dart';
import '../../core/session/session_scope.dart';
import '../../core/widgets/brand.dart';
import '../../core/widgets/ui.dart';
import '../fees/fees.dart';
import '../fees/fees_repository.dart';
import '../wallet/wallet.dart';
import '../wallet/wallet_repository.dart';
import 'online_payment.dart';
import 'pay_online.dart';

/// Demande comment payer, en annonçant les frais des deux chemins avant de choisir.
///
/// Personne ne doit découvrir un montant après coup : le solde et le mobile money n'ont pas
/// le même coût, et l'écart se voit ici, avant la confirmation.
Future<bool> choosePayment(
  BuildContext context, {
  required int amount,
  required String purpose,
  required Future<OnlinePayment> Function(PaymentRepository payments) startOnline,
  required Future<void> Function(PaymentRepository payments) payWithBalance,
  String? onlineOperation = FeeOperations.contributionOnline,
  String? balanceOperation = FeeOperations.contributionWallet,
}) async {
  final choice = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _PayChoiceSheet(
      amount: amount,
      purpose: purpose,
      payWithBalance: payWithBalance,
      onlineOperation: onlineOperation,
      balanceOperation: balanceOperation,
    ),
  );

  if (choice == _paidFromBalance) return true;
  if (choice != _payByMobileMoney || !context.mounted) return false;

  // La page de paiement s'ouvre une fois la feuille refermée, sur l'écran qui l'a demandée.
  return payOnline(context, start: startOnline);
}

const _paidFromBalance = 'solde';
const _payByMobileMoney = 'mobile-money';

class _Options {
  const _Options(this.wallet, this.online, this.fromBalance);

  final WalletSummary wallet;

  /// Nuls quand l'opération ne porte aucun frais à annoncer, comme la participation
  /// à une cagnotte : le ticket est encaissé au franc près.
  final FeeQuote? online;
  final FeeQuote? fromBalance;
}

class _PayChoiceSheet extends StatefulWidget {
  const _PayChoiceSheet({
    required this.amount,
    required this.purpose,
    required this.payWithBalance,
    required this.onlineOperation,
    required this.balanceOperation,
  });

  final int amount;
  final String purpose;
  final Future<void> Function(PaymentRepository payments) payWithBalance;
  final String? onlineOperation;
  final String? balanceOperation;

  @override
  State<_PayChoiceSheet> createState() => _PayChoiceSheetState();
}

class _PayChoiceSheetState extends State<_PayChoiceSheet> {
  late Future<_Options> _future;
  bool _paying = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future = _load();
  }

  Future<_Options> _load() async {
    final session = SessionScope.read(context);
    final fees = FeesRepository(session.api, organizationId: session.currentOrganization?.id);

    final wallet = await WalletRepository(session.api).summary();
    final online = widget.onlineOperation == null
        ? null
        : await fees.simulate(operation: widget.onlineOperation!, amount: widget.amount);
    final fromBalance = widget.balanceOperation == null
        ? null
        : await fees.simulate(operation: widget.balanceOperation!, amount: widget.amount);

    return _Options(wallet, online, fromBalance);
  }

  Future<void> _payFromBalance() async {
    final session = SessionScope.read(context);
    setState(() => _paying = true);

    try {
      await widget.payWithBalance(PaymentRepository(session.api, session.currentOrganization?.id));
      if (!mounted) return;
      Navigator.pop(context, _paidFromBalance);
      showDone(context, 'Réglé depuis votre solde.');
    } catch (error) {
      if (!mounted) return;
      setState(() => _paying = false);
      showError(context, error);
    }
  }

  void _payOnline() => Navigator.pop(context, _payByMobileMoney);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: FutureBuilder<_Options>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.hasError && !snapshot.hasData) {
            // Sans la grille des frais, le paiement en ligne reste possible.
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(errorText(snapshot.error!), textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(onPressed: _payOnline, child: const Text('Payer par mobile money')),
                  ),
                ],
              ),
            );
          }

          if (!snapshot.hasData) {
            return const SizedBox(height: 220, child: LoadingView());
          }

          final options = snapshot.requireData;
          final due = options.fromBalance?.totalAmount ?? widget.amount;
          final enough = options.wallet.balance >= due;

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Comment payer ?', style: theme.textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(
                  '${widget.purpose} : ${fcfa(widget.amount)}',
                  style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.muted),
                ),
                const SizedBox(height: 18),
                _Option(
                  icon: Icons.account_balance_wallet_outlined,
                  title: 'Avec mon solde',
                  detail: enough
                      ? (options.fromBalance?.summary ?? 'Vous payez ${fcfa(due)}.')
                      : 'Solde insuffisant : ${fcfa(options.wallet.balance)} disponibles.',
                  tone: enough ? Tone.positive : Tone.neutral,
                  onTap: enough && !_paying ? _payFromBalance : null,
                  busy: _paying,
                ),
                const SizedBox(height: 12),
                _Option(
                  icon: Icons.smartphone_rounded,
                  title: 'Par mobile money',
                  detail: options.online?.summary ?? 'Vous payez ${fcfa(widget.amount)}.',
                  tone: Tone.neutral,
                  onTap: _paying ? null : _payOnline,
                ),
                if (options.fromBalance != null && options.online != null) ...[
                  const SizedBox(height: 14),
                  Text(
                    'Payer depuis le solde coûte moins cher : l’argent est déjà dans l’application.',
                    style: theme.textTheme.bodySmall?.copyWith(color: AppColors.muted),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Option extends StatelessWidget {
  const _Option({
    required this.icon,
    required this.title,
    required this.detail,
    required this.tone,
    required this.onTap,
    this.busy = false,
  });

  final IconData icon;
  final String title;
  final String detail;
  final Tone tone;
  final VoidCallback? onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = toneColors(tone);
    final enabled = onTap != null;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Panel(
        color: enabled ? Colors.white : AppColors.cotton,
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: colors.background, shape: BoxShape.circle),
              child: Icon(icon, size: 20, color: colors.foreground),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppType.sans(bold: true)),
                  const SizedBox(height: 2),
                  Text(detail, style: theme.textTheme.bodySmall?.copyWith(color: AppColors.muted)),
                ],
              ),
            ),
            if (busy) const ButtonSpinner() else if (enabled) const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }
}
