import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme.dart';
import '../../core/api/api_exception.dart';
import '../../core/format.dart';
import '../../core/session/session_scope.dart';
import '../../core/widgets/brand.dart';
import '../../core/widgets/picker_sheet.dart';
import '../../core/widgets/ui.dart';
import '../organizations/organization.dart';
import '../tontines/models.dart' show PaymentMethod;
import 'cagnotte.dart';
import 'cagnotte_repository.dart';
import 'prize_draw.dart';

/// Membres de l'organisation courante, triés par nom.
Future<List<MemberUser>> loadOrganizationMembers(BuildContext context) async {
  final session = SessionScope.read(context);
  final memberships = await session.organizations.members(session.currentOrganization!.id);
  return [for (final membership in memberships) membership.user]..sort((a, b) => a.displayName.compareTo(b.displayName));
}

Future<MemberUser?> pickMember(BuildContext context, List<MemberUser> members, {required String title, Set<int> exclude = const {}}) {
  return showPickerSheet<MemberUser>(
    context,
    title: title,
    items: [for (final member in members) if (!exclude.contains(member.id)) member],
    label: (member) => member.displayName,
    subtitle: (member) => phoneDisplay(member.phone),
    leading: (member) => MemberAvatar(name: member.name),
    emptyMessage: 'Aucun membre disponible.',
  );
}

/// Champ qui ouvre la liste des membres.
class MemberField extends StatelessWidget {
  const MemberField({super.key, required this.label, required this.member, required this.onTap, this.errorText});

  final String label;
  final MemberUser? member;
  final VoidCallback? onTap;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          errorText: errorText,
          enabled: onTap != null,
          suffixIcon: onTap == null ? null : const Icon(Icons.expand_more_rounded),
        ),
        child: member == null
            ? Text('Choisir un membre', style: AppType.sans(color: AppColors.muted))
            : Row(
                children: [
                  MemberAvatar(name: member!.name, size: 28),
                  const SizedBox(width: 10),
                  Expanded(child: Text(member!.displayName, style: AppType.sans(bold: true))),
                ],
              ),
      ),
    );
  }
}

class _PaymentMethodChips extends StatelessWidget {
  const _PaymentMethodChips({required this.value, required this.onChanged});

  final PaymentMethod value;
  final ValueChanged<PaymentMethod> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final method in PaymentMethod.values)
          ChoiceChip(
            label: Text(method.label),
            selected: value == method,
            showCheckmark: false,
            onSelected: (_) => onChanged(method),
          ),
      ],
    );
  }
}

Map<String, String> _errorsOf(ApiException error) => error.fieldErrors.isEmpty
    ? {'general': error.message}
    : {for (final entry in error.fieldErrors.entries) entry.key: entry.value.first};

/// Le trésorier enregistre ou corrige une participation. Retourne true si elle a été enregistrée.
Future<bool?> showCagnotteContributionSheet(
  BuildContext context, {
  required CagnotteRepository repository,
  required Cagnotte cagnotte,
  CagnotteContribution? contribution,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _ContributionSheet(repository: repository, cagnotte: cagnotte, contribution: contribution),
  );
}

class _ContributionSheet extends StatefulWidget {
  const _ContributionSheet({required this.repository, required this.cagnotte, this.contribution});

  final CagnotteRepository repository;
  final Cagnotte cagnotte;
  final CagnotteContribution? contribution;

  @override
  State<_ContributionSheet> createState() => _ContributionSheetState();
}

class _ContributionSheetState extends State<_ContributionSheet> {
  late final TextEditingController _amount;
  late final TextEditingController _reference;
  late PaymentMethod _method;
  MemberUser? _member;
  List<MemberUser>? _members;
  bool _saving = false;
  Map<String, String> _errors = const {};

  Cagnotte get _cagnotte => widget.cagnotte;
  bool get _editing => widget.contribution != null;

  @override
  void initState() {
    super.initState();
    final contribution = widget.contribution;
    _amount = TextEditingController(text: '${contribution?.amount ?? _cagnotte.ticketPrice ?? _cagnotte.minAmount}');
    _reference = TextEditingController(text: contribution?.reference ?? '');
    _method = contribution?.method ?? PaymentMethod.cash;
    _member = contribution?.user;
  }

  @override
  void dispose() {
    _amount.dispose();
    _reference.dispose();
    super.dispose();
  }

  Future<void> _chooseMember() async {
    try {
      _members ??= await loadOrganizationMembers(context);
    } catch (error) {
      if (mounted) setState(() => _errors = {'user_id': errorText(error)});
      return;
    }
    if (!mounted) return;
    final member = await pickMember(context, _members!, title: 'Qui participe ?');
    if (member != null) setState(() => _member = member);
  }

  Future<void> _submit() async {
    final amount = int.tryParse(_amount.text);
    if (_member == null) {
      setState(() => _errors = {'user_id': 'Choisissez la personne qui participe.'});
      return;
    }
    if (amount == null || amount < _cagnotte.minAmount) {
      setState(() => _errors = {'amount': 'La participation minimum est de ${fcfa(_cagnotte.minAmount)}.'});
      return;
    }

    setState(() {
      _saving = true;
      _errors = const {};
    });
    try {
      if (_editing) {
        await widget.repository.updateContribution(_cagnotte.id, widget.contribution!.id,
            amount: amount, method: _method, reference: _reference.text);
      } else {
        await widget.repository.recordContribution(_cagnotte.id,
            userId: _member!.id, amount: amount, method: _method, reference: _reference.text);
      }
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _errors = _errorsOf(error);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final amount = int.tryParse(_amount.text) ?? 0;
    final price = _cagnotte.ticketPrice;
    final tickets = PrizeDraw.ticketsFor(amount, price);

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 0, 24, 24 + MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_editing ? 'Modifier la participation' : 'Enregistrer une participation', style: theme.textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(
              _cagnotte.isPrize
                  ? 'Ticket à ${fcfa(price ?? 0)} : chaque tranche complète donne un ticket.'
                  : 'Participation libre, à partir de ${fcfa(_cagnotte.minAmount)}.',
              style: theme.textTheme.bodyLarge?.copyWith(color: AppColors.muted),
            ),
            const SizedBox(height: 20),
            MemberField(
              label: 'Participant',
              member: _member,
              onTap: _editing ? null : _chooseMember,
              errorText: _errors['user_id'],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _amount,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: AppType.sans(size: 20, bold: true, tabular: true),
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(labelText: 'Montant reçu', suffixText: 'FCFA', errorText: _errors['amount']),
            ),
            if (_cagnotte.isPrize && price != null && price > 0) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final count in const [1, 2, 5, 10])
                    ActionChip(
                      label: Text(countLabel(count, 'ticket', 'tickets')),
                      onPressed: () => setState(() => _amount.text = '${count * price}'),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                amount % price == 0
                    ? 'Donne ${countLabel(tickets, 'ticket', 'tickets')}.'
                    : 'Donne ${countLabel(tickets, 'ticket', 'tickets')}. Les ${fcfa(amount % price)} restants ne donnent pas de ticket.',
                style: AppType.sans(bold: true, color: AppColors.goldText),
              ),
            ],
            const SizedBox(height: 14),
            Text('Moyen de paiement', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            _PaymentMethodChips(value: _method, onChanged: (method) => setState(() => _method = method)),
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
                child: _saving ? const ButtonSpinner() : const Text('Enregistrer'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Remise de fonds (bénéficiaire) ou d'un gain (gagnant) : moyen de paiement, référence et, si demandé, montant.
Future<bool?> showTransferSheet(
  BuildContext context, {
  required String title,
  required String message,
  required String submitLabel,
  required Future<void> Function(int? amount, PaymentMethod method, String reference) onSubmit,
  int? initialAmount,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _TransferSheet(
      title: title,
      message: message,
      submitLabel: submitLabel,
      onSubmit: onSubmit,
      initialAmount: initialAmount,
    ),
  );
}

class _TransferSheet extends StatefulWidget {
  const _TransferSheet({
    required this.title,
    required this.message,
    required this.submitLabel,
    required this.onSubmit,
    this.initialAmount,
  });

  final String title;
  final String message;
  final String submitLabel;
  final Future<void> Function(int? amount, PaymentMethod method, String reference) onSubmit;
  final int? initialAmount;

  @override
  State<_TransferSheet> createState() => _TransferSheetState();
}

class _TransferSheetState extends State<_TransferSheet> {
  late final TextEditingController _amount = TextEditingController(text: '${widget.initialAmount ?? ''}');
  final _reference = TextEditingController();
  PaymentMethod _method = PaymentMethod.cash;
  bool _saving = false;
  Map<String, String> _errors = const {};

  @override
  void dispose() {
    _amount.dispose();
    _reference.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final amount = widget.initialAmount == null ? null : int.tryParse(_amount.text);
    if (widget.initialAmount != null && (amount == null || amount <= 0)) {
      setState(() => _errors = {'amount': 'Saisissez le montant remis.'});
      return;
    }

    setState(() {
      _saving = true;
      _errors = const {};
    });
    try {
      await widget.onSubmit(amount, _method, _reference.text);
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _errors = _errorsOf(error);
        });
      }
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
            Text(widget.title, style: theme.textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(widget.message, style: theme.textTheme.bodyLarge?.copyWith(color: AppColors.muted)),
            const SizedBox(height: 20),
            if (widget.initialAmount != null) ...[
              TextField(
                controller: _amount,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: AppType.sans(size: 20, bold: true, tabular: true),
                decoration: InputDecoration(labelText: 'Montant remis', suffixText: 'FCFA', errorText: _errors['amount']),
              ),
              const SizedBox(height: 14),
            ],
            Text('Moyen de remise', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            _PaymentMethodChips(value: _method, onChanged: (method) => setState(() => _method = method)),
            const SizedBox(height: 16),
            TextField(
              controller: _reference,
              decoration: InputDecoration(labelText: 'Référence (facultatif)', errorText: _errors['reference']),
            ),
            if (_errors['general'] != null || _errors['method'] != null) ...[
              const SizedBox(height: 12),
              Text(_errors['general'] ?? _errors['method']!, style: AppType.sans(color: AppColors.chili)),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _submit,
                child: _saving ? const ButtonSpinner() : Text(widget.submitLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Liste des rangs d'une cagnotte à gagnants, chacun tiré au sort ou attribué à un membre.
class RankDesignationsEditor extends StatelessWidget {
  const RankDesignationsEditor({
    super.key,
    required this.split,
    required this.designations,
    required this.onChoose,
    required this.onClear,
    this.amounts,
  });

  final List<double> split;
  final Map<int, MemberUser> designations;
  final ValueChanged<int> onChoose;
  final ValueChanged<int> onClear;

  /// Gains en francs, quand ils sont connus.
  final List<int>? amounts;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < split.length; i++) ...[
            if (i > 0) const Divider(indent: 64),
            ListTile(
              contentPadding: const EdgeInsets.fromLTRB(16, 2, 8, 2),
              leading: RankBadge(rank: i + 1),
              title: Text(
                amounts == null
                    ? '${ordinal(i + 1)} gain, ${percentLabel(split[i])}'
                    : '${ordinal(i + 1)} gain, ${fcfa(amounts![i])}',
              ),
              subtitle: Text(
                designations[i + 1] == null ? 'Tiré au sort' : 'Attribué à ${designations[i + 1]!.displayName}',
                style: AppType.sans(
                  size: 14,
                  bold: designations[i + 1] != null,
                  color: designations[i + 1] == null ? AppColors.muted : AppColors.indigo,
                ),
              ),
              trailing: designations[i + 1] == null
                  ? TextButton(onPressed: () => onChoose(i + 1), child: const Text('Attribuer'))
                  : IconButton(
                      tooltip: 'Remettre au tirage',
                      onPressed: () => onClear(i + 1),
                      icon: const Icon(Icons.close_rounded),
                    ),
            ),
          ],
        ],
      ),
    );
  }
}

class RankBadge extends StatelessWidget {
  const RankBadge({super.key, required this.rank});

  final int rank;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: rank == 1 ? AppColors.gold : AppColors.goldSoft, shape: BoxShape.circle),
      child: Text(
        ordinal(rank),
        style: AppType.sans(size: 13, bold: true, color: rank == 1 ? AppColors.ink : AppColors.goldText, tabular: true),
      ),
    );
  }
}

/// Modifie les rangs attribués d'une cagnotte qui n'a encore aucune participation.
Future<bool?> showDesignationsSheet(BuildContext context, {required CagnotteRepository repository, required Cagnotte cagnotte}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _DesignationsSheet(repository: repository, cagnotte: cagnotte),
  );
}

class _DesignationsSheet extends StatefulWidget {
  const _DesignationsSheet({required this.repository, required this.cagnotte});

  final CagnotteRepository repository;
  final Cagnotte cagnotte;

  @override
  State<_DesignationsSheet> createState() => _DesignationsSheetState();
}

class _DesignationsSheetState extends State<_DesignationsSheet> {
  late final Map<int, MemberUser> _chosen = {
    for (final prize in widget.cagnotte.prizes)
      if (prize.designatedUserId != null)
        prize.rank: MemberUser(id: prize.designatedUserId!, phone: '', name: prize.designatedName),
  };
  List<MemberUser>? _members;
  bool _saving = false;
  String? _error;

  Future<void> _choose(int rank) async {
    try {
      _members ??= await loadOrganizationMembers(context);
    } catch (error) {
      if (mounted) setState(() => _error = errorText(error));
      return;
    }
    if (!mounted) return;
    final taken = {for (final entry in _chosen.entries) if (entry.key != rank) entry.value.id};
    final member = await pickMember(context, _members!, title: '${capitalize(ordinal(rank))} gain', exclude: taken);
    if (member != null) setState(() => _chosen[rank] = member);
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.repository.setDesignations(widget.cagnotte.id, {for (final entry in _chosen.entries) entry.key: entry.value.id});
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = error.displayMessage;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cagnotte = widget.cagnotte;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Rangs attribués', style: theme.textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(
              'Tous les membres verront ces noms avant de participer. Dès la première participation, ils ne pourront plus changer.',
              style: theme.textTheme.bodyLarge?.copyWith(color: AppColors.muted),
            ),
            const SizedBox(height: 16),
            RankDesignationsEditor(
              split: [for (final prize in cagnotte.prizes) prize.percent],
              designations: _chosen,
              onChoose: _choose,
              onClear: (rank) => setState(() => _chosen.remove(rank)),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: AppType.sans(color: AppColors.chili)),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving ? const ButtonSpinner() : const Text('Publier ces rangs'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
