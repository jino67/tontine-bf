import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme.dart';
import '../../content/cagnotte_guide.dart';
import '../../core/api/api_exception.dart';
import '../../core/format.dart';
import '../../core/widgets/brand.dart';
import '../../core/widgets/ui.dart';
import '../organizations/organization.dart';
import 'cagnotte.dart';
import 'cagnotte_detail_screen.dart';
import 'cagnotte_repository.dart';
import 'cagnotte_sheets.dart';
import 'prize_draw.dart';

class CreateCagnotteScreen extends StatefulWidget {
  const CreateCagnotteScreen({super.key, required this.repository});

  final CagnotteRepository repository;

  @override
  State<CreateCagnotteScreen> createState() => _CreateCagnotteScreenState();
}

class _CreateCagnotteScreenState extends State<CreateCagnotteScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _target = TextEditingController();
  final _minAmount = TextEditingController(text: '500');
  final _beneficiaryName = TextEditingController();
  final _ticketPrice = TextEditingController(text: '500');
  final _fee = TextEditingController(text: '0');

  CagnotteMode _mode = CagnotteMode.solidarity;
  CagnotteDuration _duration = CagnotteDuration.week;
  DateTime _endsAt = DateTime.now().add(const Duration(days: 3));
  bool _beneficiaryIsMember = true;
  MemberUser? _beneficiary;
  int _winnersCount = 3;
  final Map<int, MemberUser> _designations = {};
  List<MemberUser>? _members;
  bool _saving = false;
  Map<String, String> _serverErrors = const {};

  bool get _prize => _mode == CagnotteMode.prize;

  @override
  void dispose() {
    for (final controller in [_title, _description, _target, _minAmount, _beneficiaryName, _ticketPrice, _fee]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<List<MemberUser>?> _loadMembers() async {
    try {
      return _members ??= await loadOrganizationMembers(context);
    } catch (error) {
      if (mounted) showError(context, error);
      return null;
    }
  }

  Future<void> _chooseBeneficiary() async {
    final members = await _loadMembers();
    if (members == null || !mounted) return;
    final member = await pickMember(context, members, title: 'Au profit de qui ?');
    if (member != null) setState(() => _beneficiary = member);
  }

  Future<void> _chooseDesignation(int rank) async {
    final members = await _loadMembers();
    if (members == null || !mounted) return;
    final taken = {for (final entry in _designations.entries) if (entry.key != rank) entry.value.id};
    final member = await pickMember(context, members, title: '${capitalize(ordinal(rank))} gain', exclude: taken);
    if (member != null) setState(() => _designations[rank] = member);
  }

  void _setWinners(int count) => setState(() {
        _winnersCount = count.clamp(1, 10);
        _designations.removeWhere((rank, _) => rank > _winnersCount);
      });

  Future<void> _pickEndsAt() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final date = await showDatePicker(
      context: context,
      initialDate: _endsAt,
      firstDate: today,
      lastDate: today.add(const Duration(days: 365)),
      helpText: 'Fin de la collecte',
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_endsAt), helpText: 'Heure de fin');
    if (time == null) return;
    setState(() => _endsAt = DateTime(date.year, date.month, date.day, time.hour, time.minute));
  }

  String get _endLabel => switch (_duration) {
        CagnotteDuration.flash => 'dans 24 heures',
        CagnotteDuration.week => 'dans 7 jours',
        CagnotteDuration.month => 'dans 30 jours',
        CagnotteDuration.custom => 'le ${dateAndTime(_endsAt)}',
      };

  String _summary() {
    if (!_prize) {
      final who = _beneficiaryIsMember ? _beneficiary?.displayName : _beneficiaryName.text.trim();
      final min = int.tryParse(_minAmount.text) ?? 0;
      return 'La collecte se termine $_endLabel. Chacun participe à partir de ${fcfa(min)}'
          '${(who ?? '').isEmpty ? '.' : ', au profit de $who.'} Les fonds sont remis à la clôture.';
    }

    final price = int.tryParse(_ticketPrice.text) ?? 0;
    final fee = int.tryParse(_fee.text) ?? 0;
    if (price <= 0) return 'Renseignez le prix du ticket pour voir un exemple de gains.';
    final amounts = PrizeDraw.prizeAmounts(PrizeDraw.pot(price * 20, fee), PrizeDraw.defaultSplit(_winnersCount));
    final gains = [for (var i = 0; i < amounts.length; i++) '${ordinal(i + 1)} ${fcfa(amounts[i])}'].join(', ');
    return 'La collecte se termine $_endLabel. Exemple avec 20 tickets vendus, soit ${fcfa(price * 20)}'
        '${fee > 0 ? ' dont $fee % de commission' : ''} : $gains.';
  }

  Future<void> _submit() async {
    setState(() => _serverErrors = const {});
    if (!_formKey.currentState!.validate()) return;
    if (!_prize && _beneficiaryIsMember && _beneficiary == null) {
      setState(() => _serverErrors = {'beneficiary_user_id': 'Choisissez le membre bénéficiaire.'});
      return;
    }
    if (_duration == CagnotteDuration.custom && !_endsAt.isAfter(DateTime.now())) {
      setState(() => _serverErrors = {'ends_at': 'Choisissez une date de fin à venir.'});
      return;
    }

    final navigator = Navigator.of(context);
    setState(() => _saving = true);
    try {
      final description = _description.text.trim();
      final cagnotte = await widget.repository.create(
        CagnotteDraft(
          mode: _mode,
          title: _title.text.trim(),
          description: description.isEmpty ? null : description,
          duration: _duration,
          endsAt: _endsAt,
          targetAmount: int.tryParse(_target.text),
          minAmount: int.tryParse(_minAmount.text),
          beneficiaryUserId: _beneficiaryIsMember ? _beneficiary?.id : null,
          beneficiaryName: _beneficiaryIsMember ? null : _beneficiaryName.text.trim(),
          ticketPrice: int.tryParse(_ticketPrice.text),
          winnersCount: _winnersCount,
          feePercent: int.tryParse(_fee.text),
          designations: {for (final entry in _designations.entries) entry.key: entry.value.id},
        ),
      );
      navigator.pushReplacement(
        MaterialPageRoute(builder: (_) => CagnotteDetailScreen(repository: widget.repository, cagnotteId: cagnotte.id)),
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _serverErrors = {for (final entry in error.fieldErrors.entries) entry.key: entry.value.first};
      });
      if (error.fieldErrors.isEmpty) {
        showError(context, error);
      } else if (_serverErrors.keys.any((key) => key.startsWith('designations') || key == 'prize_split')) {
        showError(context, error);
      }
    }
  }

  String? _number(String? value, {required int min, required int max, required String unit}) {
    final number = int.tryParse(value ?? '');
    if (number == null || number < min) return 'Au moins $min $unit.';
    if (number > max) return 'Au plus $max $unit.';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Nouvelle cagnotte')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
          children: [
            Text('Type de cagnotte', style: theme.textTheme.titleMedium),
            const SizedBox(height: 10),
            for (final mode in CagnotteMode.values)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _ModeOption(mode: mode, selected: mode == _mode, onTap: () => setState(() => _mode = mode)),
              ),
            const SizedBox(height: 12),
            Text('Informations', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            TextFormField(
              controller: _title,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Titre',
                hintText: _prize ? 'Cagnotte Flash du vendredi' : 'Soutien à la famille de Mariam',
                errorText: _serverErrors['title'],
              ),
              validator: (value) => (value ?? '').trim().isEmpty ? 'Donnez un titre à la cagnotte.' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _description,
              textCapitalization: TextCapitalization.sentences,
              maxLines: 3,
              minLines: 1,
              decoration: InputDecoration(labelText: 'Description (facultatif)', errorText: _serverErrors['description']),
            ),
            const SizedBox(height: 18),
            Text('Durée', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final duration in CagnotteDuration.values)
                  ChoiceChip(
                    label: Text(duration.label),
                    selected: duration == _duration,
                    showCheckmark: false,
                    onSelected: (_) => setState(() => _duration = duration),
                  ),
              ],
            ),
            if (_duration == CagnotteDuration.custom) ...[
              const SizedBox(height: 14),
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: _pickEndsAt,
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Fin de la collecte',
                    errorText: _serverErrors['ends_at'],
                    suffixIcon: const Icon(Icons.event_rounded),
                  ),
                  child: Text(dateAndTime(_endsAt), style: theme.textTheme.bodyLarge),
                ),
              ),
            ],
            const SizedBox(height: 14),
            TextFormField(
              controller: _target,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(labelText: 'Objectif (facultatif)', suffixText: 'FCFA', errorText: _serverErrors['target_amount']),
              validator: (value) => (value ?? '').isEmpty ? null : _number(value, min: 100, max: 100000000, unit: 'FCFA'),
            ),
            const SizedBox(height: 24),
            if (_prize) ..._prizeFields(theme) else ..._solidarityFields(theme),
            const SizedBox(height: 18),
            Panel(
              color: AppColors.goldSoft,
              borderColor: AppColors.goldSoft,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline_rounded, color: AppColors.goldText),
                  const SizedBox(width: 12),
                  Expanded(child: Text(_summary(), style: theme.textTheme.bodyMedium)),
                ],
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _saving ? null : _submit,
              child: _saving ? const ButtonSpinner() : const Text('Ouvrir la cagnotte'),
            ),
            const SizedBox(height: 10),
            Text('Le compte à rebours démarre dès l’ouverture.', textAlign: TextAlign.center, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }

  List<Widget> _solidarityFields(ThemeData theme) => [
        Text('Bénéficiaire', style: theme.textTheme.titleMedium),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              label: const Text('Un membre'),
              selected: _beneficiaryIsMember,
              showCheckmark: false,
              onSelected: (_) => setState(() => _beneficiaryIsMember = true),
            ),
            ChoiceChip(
              label: const Text('Une personne extérieure'),
              selected: !_beneficiaryIsMember,
              showCheckmark: false,
              onSelected: (_) => setState(() => _beneficiaryIsMember = false),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_beneficiaryIsMember)
          MemberField(
            label: 'Membre bénéficiaire',
            member: _beneficiary,
            onTap: _chooseBeneficiary,
            errorText: _serverErrors['beneficiary_user_id'],
          )
        else
          TextFormField(
            controller: _beneficiaryName,
            textCapitalization: TextCapitalization.words,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(labelText: 'Nom du bénéficiaire', errorText: _serverErrors['beneficiary_name']),
            validator: (value) => (value ?? '').trim().isEmpty ? 'Indiquez le nom du bénéficiaire.' : null,
          ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _minAmount,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: (_) => setState(() {}),
          style: AppType.sans(size: 17, bold: true, tabular: true),
          decoration: InputDecoration(labelText: 'Participation minimum', suffixText: 'FCFA', errorText: _serverErrors['min_amount']),
          validator: (value) => _number(value, min: 100, max: 10000000, unit: 'FCFA'),
        ),
      ];

  List<Widget> _prizeFields(ThemeData theme) => [
        Text('Tickets et gains', style: theme.textTheme.titleMedium),
        const SizedBox(height: 12),
        TextFormField(
          controller: _ticketPrice,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: (_) => setState(() {}),
          style: AppType.sans(size: 17, bold: true, tabular: true),
          decoration: InputDecoration(labelText: 'Prix du ticket', suffixText: 'FCFA', errorText: _serverErrors['ticket_price']),
          validator: (value) => _number(value, min: 50, max: 1000000, unit: 'FCFA'),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(child: Text('Nombre de gagnants', style: theme.textTheme.titleSmall)),
            IconButton.outlined(
              tooltip: 'Un gagnant de moins',
              onPressed: _winnersCount > 1 ? () => _setWinners(_winnersCount - 1) : null,
              icon: const Icon(Icons.remove_rounded),
            ),
            SizedBox(
              width: 44,
              child: Text('$_winnersCount', textAlign: TextAlign.center, style: AppType.sans(size: 20, bold: true, tabular: true)),
            ),
            IconButton.outlined(
              tooltip: 'Un gagnant de plus',
              onPressed: _winnersCount < 10 ? () => _setWinners(_winnersCount + 1) : null,
              icon: const Icon(Icons.add_rounded),
            ),
          ],
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _fee,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: 'Commission de l’organisation',
            suffixText: '%',
            helperText: feeExplanation,
            helperMaxLines: 3,
            errorText: _serverErrors['fee_percent'],
          ),
          validator: (value) => _number(value, min: 0, max: 30, unit: '%'),
        ),
        const SizedBox(height: 18),
        Text('Répartition des gains', style: theme.textTheme.titleSmall),
        const SizedBox(height: 4),
        Text(designationRule, style: theme.textTheme.bodySmall),
        const SizedBox(height: 10),
        RankDesignationsEditor(
          split: PrizeDraw.defaultSplit(_winnersCount),
          designations: _designations,
          onChoose: _chooseDesignation,
          onClear: (rank) => setState(() => _designations.remove(rank)),
        ),
      ];
}

class _ModeOption extends StatelessWidget {
  const _ModeOption({required this.mode, required this.selected, required this.onTap});

  final CagnotteMode mode;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? AppColors.leafSoft : Colors.white,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: selected ? AppColors.leaf : AppColors.line, width: selected ? 2 : 1),
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(mode.icon, color: selected ? AppColors.leafDeep : AppColors.muted),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(mode.label, style: theme.textTheme.titleMedium),
                      const SizedBox(height: 2),
                      Text(cagnotteGuideFor(mode).summary, style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.muted)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(selected ? Icons.check_circle_rounded : Icons.circle_outlined, color: selected ? AppColors.leaf : AppColors.line),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
