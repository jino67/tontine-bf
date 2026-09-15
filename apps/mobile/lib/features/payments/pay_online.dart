import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/theme.dart';
import '../../core/format.dart';
import '../../core/session/session_scope.dart';
import '../../core/widgets/brand.dart';
import '../../core/widgets/ui.dart';
import 'online_payment.dart';

/// Crée le paiement, ouvre la page PayDunya, puis vérifie le statut au retour dans l'application.
/// Retourne true si le paiement est validé.
Future<bool> payOnline(BuildContext context, {required Future<OnlinePayment> Function(PaymentRepository payments) start}) async {
  final session = SessionScope.read(context);
  final payments = PaymentRepository(session.api, session.currentOrganization!.id);

  final paid = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _PaymentFlowSheet(payments: payments, start: () => start(payments)),
  );
  return paid ?? false;
}

class _PaymentFlowSheet extends StatefulWidget {
  const _PaymentFlowSheet({required this.payments, required this.start});

  final PaymentRepository payments;
  final Future<OnlinePayment> Function() start;

  @override
  State<_PaymentFlowSheet> createState() => _PaymentFlowSheetState();
}

class _PaymentFlowSheetState extends State<_PaymentFlowSheet> with WidgetsBindingObserver {
  OnlinePayment? _payment;
  Object? _error;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _begin();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Au retour depuis la page de paiement, le statut est vérifié sans que le membre ait à toucher quoi que ce soit.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && (_payment?.isPending ?? false)) _check();
  }

  Future<void> _begin() async {
    try {
      final payment = await widget.start();
      if (!mounted) return;
      setState(() => _payment = payment);
      await _open(payment.checkoutUrl);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  Future<void> _open(String? url) async {
    if (url == null) return;
    final opened = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    if (!opened && mounted) showDone(context, 'Impossible d’ouvrir la page de paiement. Réessayez.');
  }

  Future<void> _check() async {
    final payment = _payment;
    if (payment == null || _checking) return;
    setState(() => _checking = true);
    try {
      final updated = await widget.payments.status(payment.id);
      if (mounted) setState(() => _payment = updated);
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final payment = _payment;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
      child: SingleChildScrollView(
        child: switch ((payment, _error)) {
          (null, final Object error) => _Step(
              icon: Icons.cloud_off_rounded,
              tone: Tone.danger,
              title: 'Paiement impossible',
              message: errorText(error),
              actions: [OutlinedButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Fermer'))],
            ),
          (null, _) => const _Step(
              icon: Icons.lock_outline_rounded,
              tone: Tone.indigo,
              title: 'Préparation du paiement',
              message: 'Ouverture de la page sécurisée PayDunya…',
              actions: [Center(child: CircularProgressIndicator())],
            ),
          (final OnlinePayment payment, _) => _forStatus(payment),
        },
      ),
    );
  }

  Widget _forStatus(OnlinePayment payment) {
    return switch (payment.status) {
      OnlinePaymentStatus.pending => _Step(
          icon: Icons.phone_iphone_rounded,
          tone: Tone.gold,
          title: 'Paiement de ${fcfa(payment.amount)}',
          message: 'Payez sur la page PayDunya par Orange Money, Moov Money ou carte, puis revenez ici. '
              'La vérification se fait toute seule à votre retour.',
          actions: [
            FilledButton(
              onPressed: _checking ? null : _check,
              child: _checking ? const ButtonSpinner() : const Text('J’ai payé, vérifier'),
            ),
            OutlinedButton(onPressed: () => _open(payment.checkoutUrl), child: const Text('Rouvrir la page de paiement')),
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Payer plus tard')),
          ],
        ),
      OnlinePaymentStatus.paid => _Step(
          icon: Icons.verified_rounded,
          tone: Tone.positive,
          title: 'Paiement validé',
          message: payment.applied
              ? 'Votre paiement de ${fcfa(payment.amount)} est enregistré et confirmé.'
              : 'PayDunya a bien reçu ${fcfa(payment.amount)}, mais il n’a pas pu être affecté automatiquement. '
                  'Le trésorier va le régulariser.',
          actions: [
            FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Terminer')),
            if (payment.receiptUrl != null)
              TextButton(onPressed: () => _open(payment.receiptUrl), child: const Text('Voir le reçu')),
          ],
        ),
      OnlinePaymentStatus.cancelled => _Step(
          icon: Icons.block_rounded,
          tone: Tone.neutral,
          title: 'Paiement annulé',
          message: 'Aucune somme n’a été prélevée.',
          actions: [OutlinedButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Fermer'))],
        ),
      OnlinePaymentStatus.failed => _Step(
          icon: Icons.error_outline_rounded,
          tone: Tone.danger,
          title: 'Paiement non abouti',
          message: payment.failureReason ?? 'Le paiement n’a pas abouti. Vous pouvez réessayer.',
          actions: [OutlinedButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Fermer'))],
        ),
    };
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.icon, required this.tone, required this.title, required this.message, required this.actions});

  final IconData icon;
  final Tone tone;
  final String title;
  final String message;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = toneColors(tone);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(color: colors.background, shape: BoxShape.circle),
            child: Icon(icon, color: colors.foreground, size: 28),
          ),
        ),
        const SizedBox(height: 14),
        Text(title, style: theme.textTheme.titleLarge),
        const SizedBox(height: 6),
        Text(message, style: theme.textTheme.bodyLarge?.copyWith(color: AppColors.muted)),
        const SizedBox(height: 20),
        for (final action in actions) Padding(padding: const EdgeInsets.only(bottom: 8), child: action),
      ],
    );
  }
}
