import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme.dart';
import '../../core/format.dart';
import '../../core/session/session_scope.dart';
import '../../core/widgets/brand.dart';
import '../../core/widgets/ui.dart';
import '../fees/fees.dart';
import '../fees/fees_repository.dart';
import '../payments/pay_online.dart';
import 'wallet.dart';
import 'wallet_repository.dart';

/// Envoi d'argent à un autre membre, de solde à solde.
Future<void> showTransferSheet(
  BuildContext context, {
  required WalletRepository repository,
  required WalletSummary summary,
}) =>
    _open(context, _TransferSheet(repository: repository, summary: summary));

/// Retrait vers le numéro mobile money enregistré.
Future<void> showWithdrawSheet(
  BuildContext context, {
  required WalletRepository repository,
  required WalletSummary summary,
}) =>
    _open(context, _WithdrawSheet(repository: repository, summary: summary));

/// Dépôt depuis mobile money, quand il est ouvert sur ce serveur.
Future<void> showDepositSheet(
  BuildContext context, {
  required WalletRepository repository,
  required WalletSummary summary,
}) =>
    _open(context, _DepositSheet(repository: repository, summary: summary));

/// Numéro qui recevra les retraits, confirmé par un code.
Future<void> showPayoutPhoneSheet(
  BuildContext context, {
  required WalletRepository repository,
  required WalletSummary summary,
}) =>
    _open(context, _PayoutPhoneSheet(repository: repository, summary: summary));

Future<void> _open(BuildContext context, Widget sheet) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: sheet,
      ),
    );

/// Cadre commun : un titre, une explication, le contenu, et un bouton d'action.
class _SheetFrame extends StatelessWidget {
  const _SheetFrame({required this.title, required this.intro, required this.children});

  final String title;
  final String intro;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: theme.textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(intro, style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.muted)),
            const SizedBox(height: 18),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _TransferSheet extends StatefulWidget {
  const _TransferSheet({required this.repository, required this.summary});

  final WalletRepository repository;
  final WalletSummary summary;

  @override
  State<_TransferSheet> createState() => _TransferSheetState();
}

class _TransferSheetState extends State<_TransferSheet> {
  final _phone = TextEditingController();
  final _amount = TextEditingController();
  final _note = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _phone.dispose();
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final phone = normalizeBurkinaPhone(_phone.text);
    final amount = int.tryParse(_amount.text.replaceAll(RegExp(r'\s'), '')) ?? 0;

    if (phone == null) {
      showDone(context, 'Saisissez un numéro burkinabè à 8 chiffres.');
      return;
    }

    if (amount < 100 || amount > widget.summary.balance) {
      showDone(context, 'Montant impossible : votre solde est de ${fcfa(widget.summary.balance)}.');
      return;
    }

    setState(() => _sending = true);
    try {
      await widget.repository.transfer(phone: phone, amount: amount, note: _note.text.trim().isEmpty ? null : _note.text.trim());
      if (!mounted) return;
      Navigator.pop(context);
      showDone(context, '${fcfa(amount)} envoyés.');
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SheetFrame(
      title: 'Envoyer de l’argent',
      intro: 'De votre solde vers celui d’un autre membre, tout de suite et sans frais.',
      children: [
        TextField(
          controller: _phone,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(labelText: 'Numéro du destinataire', hintText: '70 12 34 56'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _amount,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            labelText: 'Montant',
            suffixText: 'FCFA',
            helperText: 'Disponible : ${fcfa(widget.summary.balance)}',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _note,
          maxLength: 120,
          decoration: const InputDecoration(labelText: 'Mot pour le destinataire (facultatif)'),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _sending ? null : _send,
            child: _sending ? const ButtonSpinner() : const Text('Envoyer'),
          ),
        ),
      ],
    );
  }
}

class _WithdrawSheet extends StatefulWidget {
  const _WithdrawSheet({required this.repository, required this.summary});

  final WalletRepository repository;
  final WalletSummary summary;

  @override
  State<_WithdrawSheet> createState() => _WithdrawSheetState();
}

class _WithdrawSheetState extends State<_WithdrawSheet> {
  final _amount = TextEditingController();
  FeeQuote? _quote;
  bool _sending = false;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  /// Les frais sont annoncés avant la confirmation, jamais découverts après.
  Future<void> _quoteFor(String value) async {
    final amount = int.tryParse(value.replaceAll(RegExp(r'\s'), '')) ?? 0;

    if (amount < widget.summary.minWithdrawal) {
      setState(() => _quote = null);
      return;
    }

    try {
      final session = SessionScope.read(context);
      final quote = await FeesRepository(session.api).simulate(
        operation: FeeOperations.withdrawal,
        amount: amount,
      );
      if (mounted) setState(() => _quote = quote);
    } catch (_) {
      // Sans réseau, le montant part quand même : l'API refera le calcul.
    }
  }

  Future<void> _withdraw() async {
    final amount = int.tryParse(_amount.text.replaceAll(RegExp(r'\s'), '')) ?? 0;

    setState(() => _sending = true);
    try {
      await widget.repository.withdraw(amount);
      if (!mounted) return;
      Navigator.pop(context);
      showDone(context, 'Retrait lancé. L’opérateur confirme dans quelques minutes.');
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.summary.canWithdraw) {
      return _SheetFrame(
        title: 'Retirer de l’argent',
        intro: 'Enregistrez d’abord le numéro mobile money qui recevra l’argent.',
        children: [
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                Navigator.pop(context);
                showPayoutPhoneSheet(context, repository: widget.repository, summary: widget.summary);
              },
              child: const Text('Enregistrer mon numéro'),
            ),
          ),
        ],
      );
    }

    return _SheetFrame(
      title: 'Retirer de l’argent',
      intro: 'Vers ${phoneDisplay(widget.summary.payoutPhone!)}, '
          '${withdrawModes[widget.summary.payoutMode] ?? widget.summary.payoutMode}.',
      children: [
        TextField(
          controller: _amount,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: _quoteFor,
          decoration: InputDecoration(
            labelText: 'Montant à recevoir',
            suffixText: 'FCFA',
            helperText: 'Disponible : ${fcfa(widget.summary.balance)} · '
                'au plus ${fcfa(widget.summary.dailyWithdrawal)} par jour',
          ),
        ),
        if (_quote != null) ...[
          const SizedBox(height: 14),
          Panel(child: Text(_quote!.summary)),
        ],
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _sending || _quote == null ? null : _withdraw,
            child: _sending ? const ButtonSpinner() : const Text('Retirer'),
          ),
        ),
      ],
    );
  }
}

class _DepositSheet extends StatefulWidget {
  const _DepositSheet({required this.repository, required this.summary});

  final WalletRepository repository;
  final WalletSummary summary;

  @override
  State<_DepositSheet> createState() => _DepositSheetState();
}

class _DepositSheetState extends State<_DepositSheet> {
  final _amount = TextEditingController();
  FeeQuote? _quote;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _quoteFor(String value) async {
    final amount = int.tryParse(value.replaceAll(RegExp(r'\s'), '')) ?? 0;

    if (amount < widget.summary.minDeposit) {
      setState(() => _quote = null);
      return;
    }

    try {
      final session = SessionScope.read(context);
      final quote = await FeesRepository(session.api).simulate(operation: FeeOperations.deposit, amount: amount);
      if (mounted) setState(() => _quote = quote);
    } catch (_) {
      // L'API refera le calcul au moment du paiement.
    }
  }

  Future<void> _deposit() async {
    final amount = int.tryParse(_amount.text.replaceAll(RegExp(r'\s'), '')) ?? 0;
    Navigator.pop(context);

    final paid = await payOnline(context, begin: () => widget.repository.deposit(amount));
    if (paid) widget.repository.revision.value++;
  }

  @override
  Widget build(BuildContext context) {
    return _SheetFrame(
      title: 'Déposer de l’argent',
      intro: 'Depuis votre compte mobile money vers votre solde.',
      children: [
        TextField(
          controller: _amount,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: _quoteFor,
          decoration: InputDecoration(
            labelText: 'Montant',
            suffixText: 'FCFA',
            helperText: 'À partir de ${fcfa(widget.summary.minDeposit)}',
          ),
        ),
        if (_quote != null) ...[
          const SizedBox(height: 14),
          Panel(child: Text(_quote!.summary)),
        ],
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _quote == null ? null : _deposit,
            child: const Text('Continuer'),
          ),
        ),
      ],
    );
  }
}

class _PayoutPhoneSheet extends StatefulWidget {
  const _PayoutPhoneSheet({required this.repository, required this.summary});

  final WalletRepository repository;
  final WalletSummary summary;

  @override
  State<_PayoutPhoneSheet> createState() => _PayoutPhoneSheetState();
}

class _PayoutPhoneSheetState extends State<_PayoutPhoneSheet> {
  late final TextEditingController _phone = TextEditingController(text: widget.summary.payoutPhone ?? '');
  final _code = TextEditingController();
  String _mode = withdrawModes.keys.first;
  bool _codeSent = false;
  bool _working = false;

  @override
  void dispose() {
    _phone.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final phone = normalizeBurkinaPhone(_phone.text);

    if (phone == null) {
      showDone(context, 'Saisissez un numéro burkinabè à 8 chiffres.');
      return;
    }

    setState(() => _working = true);
    try {
      final saved = await widget.repository.savePayoutPhone(
        phone: phone,
        mode: _mode,
        code: _codeSent && _code.text.trim().length == 6 ? _code.text.trim() : null,
      );

      if (!mounted) return;

      if (saved) {
        Navigator.pop(context);
        showDone(context, 'Numéro de retrait enregistré.');
      } else {
        setState(() => _codeSent = true);
        showDone(context, 'Un code vous a été envoyé pour confirmer ce numéro.');
      }
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SheetFrame(
      title: 'Numéro de retrait',
      intro: 'C’est la porte de sortie de votre argent : un code vous est demandé pour la changer. '
          'Le premier retrait après un changement attend 24 heures.',
      children: [
        TextField(
          controller: _phone,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(labelText: 'Numéro mobile money', hintText: '70 12 34 56'),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _mode,
          decoration: const InputDecoration(labelText: 'Opérateur'),
          items: [
            for (final entry in withdrawModes.entries)
              DropdownMenuItem(value: entry.key, child: Text(entry.value)),
          ],
          onChanged: (value) => setState(() => _mode = value ?? _mode),
        ),
        if (_codeSent) ...[
          const SizedBox(height: 12),
          TextField(
            controller: _code,
            keyboardType: TextInputType.number,
            maxLength: 6,
            decoration: const InputDecoration(labelText: 'Code reçu'),
          ),
        ],
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _working ? null : _submit,
            child: _working
                ? const ButtonSpinner()
                : Text(_codeSent ? 'Confirmer le numéro' : 'Recevoir un code'),
          ),
        ),
      ],
    );
  }
}
