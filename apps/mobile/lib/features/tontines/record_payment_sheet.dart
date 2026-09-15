import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme.dart';
import '../../core/api/api_exception.dart';
import '../../core/format.dart';
import '../../core/widgets/brand.dart';
import 'models.dart';
import 'tontine_repository.dart';

/// Le trésorier saisit le montant reçu. Retourne true si le paiement a été enregistré.
Future<bool?> showRecordPaymentSheet(
  BuildContext context, {
  required TontineRepository repository,
  required int tontineId,
  required Contribution contribution,
  required String memberName,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _RecordPaymentSheet(
      repository: repository,
      tontineId: tontineId,
      contribution: contribution,
      memberName: memberName,
    ),
  );
}

class _RecordPaymentSheet extends StatefulWidget {
  const _RecordPaymentSheet({
    required this.repository,
    required this.tontineId,
    required this.contribution,
    required this.memberName,
  });

  final TontineRepository repository;
  final int tontineId;
  final Contribution contribution;
  final String memberName;

  @override
  State<_RecordPaymentSheet> createState() => _RecordPaymentSheetState();
}

class _RecordPaymentSheetState extends State<_RecordPaymentSheet> {
  late final TextEditingController _amount;
  late final TextEditingController _reference;
  late PaymentMethod _method;
  bool _saving = false;
  Map<String, String> _errors = const {};

  int get _due => widget.contribution.amountDue;

  @override
  void initState() {
    super.initState();
    final paid = widget.contribution.amountPaid;
    _amount = TextEditingController(text: '${paid > 0 ? paid : _due}');
    _reference = TextEditingController(text: widget.contribution.reference ?? '');
    _method = widget.contribution.method ?? PaymentMethod.cash;
  }

  @override
  void dispose() {
    _amount.dispose();
    _reference.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final amount = int.tryParse(_amount.text);
    if (amount == null || amount < 0 || amount > _due) {
      setState(() => _errors = {'amount_paid': 'Saisissez un montant entre 0 et ${fcfa(_due)}.'});
      return;
    }

    setState(() {
      _saving = true;
      _errors = const {};
    });
    try {
      await widget.repository.recordPayment(
        widget.tontineId,
        widget.contribution,
        amountPaid: amount,
        method: amount > 0 ? _method : null,
        reference: _reference.text,
      );
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _errors = error.fieldErrors.isEmpty
            ? {'general': error.message}
            : {for (final entry in error.fieldErrors.entries) entry.key: entry.value.first};
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 0, 24, 24 + MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Enregistrer un paiement', style: theme.textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(
              '${widget.memberName} doit ${fcfa(_due)} pour ce tour.',
              style: theme.textTheme.bodyLarge?.copyWith(color: AppColors.muted),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _amount,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: AppType.sans(size: 20, bold: true, tabular: true),
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Montant reçu',
                suffixText: 'FCFA',
                errorText: _errors['amount_paid'],
                helperText: 'Saisissez 0 pour annuler un enregistrement.',
              ),
            ),
            if (_amount.text != '$_due')
              TextButton(
                onPressed: () => setState(() => _amount.text = '$_due'),
                style: TextButton.styleFrom(padding: EdgeInsets.zero),
                child: Text('Montant complet : ${fcfa(_due)}'),
              ),
            const SizedBox(height: 14),
            Text('Moyen de paiement', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final method in PaymentMethod.manual)
                  ChoiceChip(
                    label: Text(method.label),
                    selected: _method == method,
                    showCheckmark: false,
                    onSelected: (_) => setState(() => _method = method),
                  ),
              ],
            ),
            if (_errors['method'] != null) ...[
              const SizedBox(height: 6),
              Text(_errors['method']!, style: AppType.sans(size: 13, color: AppColors.chili)),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: _reference,
              decoration: InputDecoration(
                labelText: 'Référence (facultatif)',
                helperText: 'Pour un paiement mobile money, recopiez l’identifiant du SMS de confirmation.',
                helperMaxLines: 2,
                errorText: _errors['reference'],
              ),
            ),
            if (_errors['general'] != null) ...[
              const SizedBox(height: 12),
              Text(_errors['general']!, style: AppType.sans(color: AppColors.chili)),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _submit,
                child: _saving ? const ButtonSpinner() : const Text('Enregistrer le paiement'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
