import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme.dart';
import '../../content/tontine_guide.dart';
import '../../core/api/api_exception.dart';
import '../../core/format.dart';
import '../../core/widgets/brand.dart';
import '../../core/widgets/ui.dart';
import '../profile/guide_screen.dart';
import 'models.dart';
import 'tontine_detail_screen.dart';
import 'tontine_repository.dart';

class CreateTontineScreen extends StatefulWidget {
  const CreateTontineScreen({super.key, required this.repository});

  final TontineRepository repository;

  @override
  State<CreateTontineScreen> createState() => _CreateTontineScreenState();
}

class _CreateTontineScreenState extends State<CreateTontineScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _amount = TextEditingController();
  final _cycles = TextEditingController();
  final _maxMembers = TextEditingController();
  final _goal = TextEditingController();

  TontineType _type = TontineType.rotative;
  Frequency _frequency = Frequency.weekly;
  DateTime _startsOn = DateUtils.dateOnly(DateTime.now()).add(const Duration(days: 7));
  bool _creatorJoins = true;
  bool _saving = false;
  Map<String, String> _serverErrors = const {};

  bool get _personal => _type == TontineType.personalSavings;

  @override
  void dispose() {
    for (final controller in [_name, _amount, _cycles, _maxMembers, _goal]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: _startsOn,
      firstDate: today,
      lastDate: today.add(const Duration(days: 730)),
      helpText: 'Date du premier tour',
    );
    if (picked != null) setState(() => _startsOn = picked);
  }

  Future<void> _submit() async {
    setState(() => _serverErrors = const {});
    if (!_formKey.currentState!.validate()) return;

    final navigator = Navigator.of(context);
    setState(() => _saving = true);
    try {
      final goal = _goal.text.trim();
      final tontine = await widget.repository.create(
        TontineDraft(
          name: _name.text.trim(),
          type: _type,
          amount: int.parse(_amount.text),
          frequency: _frequency,
          startsOn: _startsOn,
          cyclesCount: int.tryParse(_cycles.text),
          maxMembers: int.tryParse(_maxMembers.text),
          goal: goal.isEmpty ? null : goal,
          creatorJoins: _personal || _creatorJoins,
        ),
      );
      navigator.pushReplacement(
        MaterialPageRoute(builder: (_) => TontineDetailScreen(repository: widget.repository, tontineId: tontine.id)),
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _serverErrors = {for (final entry in error.fieldErrors.entries) entry.key: entry.value.first};
      });
      if (error.fieldErrors.isEmpty) showError(context, error);
    }
  }

  String _summary() {
    final amount = int.tryParse(_amount.text) ?? 0;
    if (amount <= 0) return 'Renseignez le montant pour voir le récapitulatif.';
    final perPeriod = '${fcfa(amount)} ${_frequency.perPeriod}';

    if (_type.hasBeneficiaries) {
      final members = int.tryParse(_maxMembers.text);
      final order = _type == TontineType.drawOrder ? 'dans l’ordre tiré au sort' : 'à son tour';
      return members == null
          ? 'Chaque part cotise $perPeriod. Il y aura autant de tours que de parts inscrites au démarrage.'
          : 'Chaque part cotise $perPeriod. Avec $members membres à une part, chacun reçoit ${fcfa(amount * members)} $order.';
    }

    final cycles = int.tryParse(_cycles.text);
    if (cycles == null) return _personal ? 'Vous versez $perPeriod.' : 'Chaque membre verse $perPeriod.';
    final total = fcfa(amount * cycles);
    return _personal
        ? '$cycles versements de ${fcfa(amount)}, soit $total épargnés au total.'
        : 'Chaque membre verse $perPeriod pendant $cycles échéances, soit $total par membre.';
  }

  String? _required(String? value, {required int min, required int max, required String unit}) {
    final number = int.tryParse(value ?? '');
    if (number == null || number < min) return 'Au moins $min $unit.';
    if (number > max) return 'Au plus $max $unit.';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Nouvelle tontine')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
          children: [
            Text('Type de tontine', style: theme.textTheme.titleMedium),
            const SizedBox(height: 10),
            for (final type in TontineType.values)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _TypeOption(type: type, selected: type == _type, onTap: () => setState(() => _type = type)),
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => GuideScreen(initialType: _type)),
                ),
                icon: const Icon(Icons.menu_book_outlined),
                label: const Text('Comprendre les types de tontine'),
              ),
            ),
            const SizedBox(height: 12),
            Text('Informations', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Nom de la tontine',
                hintText: 'Tontine des commerçantes du marché',
                errorText: _serverErrors['name'],
              ),
              validator: (value) => (value ?? '').trim().isEmpty ? 'Donnez un nom à la tontine.' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _amount,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (_) => setState(() {}),
              style: AppType.sans(size: 17, bold: true, tabular: true),
              decoration: InputDecoration(
                labelText: _personal ? 'Montant de chaque versement' : 'Cotisation par part',
                suffixText: 'FCFA',
                errorText: _serverErrors['amount'],
              ),
              validator: (value) => _required(value, min: 100, max: 10000000, unit: 'FCFA'),
            ),
            const SizedBox(height: 18),
            Text('Fréquence', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final frequency in Frequency.values)
                  ChoiceChip(
                    label: Text(frequency.label),
                    selected: frequency == _frequency,
                    showCheckmark: false,
                    onSelected: (_) => setState(() => _frequency = frequency),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: _pickDate,
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Premier tour',
                  errorText: _serverErrors['starts_on'],
                  suffixIcon: const Icon(Icons.calendar_month_outlined),
                ),
                child: Text(capitalize('${dayAndMonth(_startsOn)} ${_startsOn.year}'), style: theme.textTheme.bodyLarge),
              ),
            ),
            if (!_type.hasBeneficiaries) ...[
              const SizedBox(height: 14),
              TextFormField(
                controller: _cycles,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: 'Nombre de versements',
                  helperText: 'Par exemple 10 versements mensuels pour 10 mois.',
                  errorText: _serverErrors['cycles_count'],
                ),
                validator: (value) => _required(value, min: 1, max: 520, unit: 'versements'),
              ),
            ],
            if (!_personal) ...[
              const SizedBox(height: 14),
              TextFormField(
                controller: _maxMembers,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: 'Nombre maximum de membres (facultatif)',
                  errorText: _serverErrors['max_members'],
                ),
                validator: (value) =>
                    (value ?? '').isEmpty ? null : _required(value, min: 2, max: 500, unit: 'membres'),
              ),
            ],
            const SizedBox(height: 14),
            TextFormField(
              controller: _goal,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Objectif (facultatif)',
                errorText: _serverErrors['goal'],
              ),
            ),
            if (!_personal) ...[
              const SizedBox(height: 6),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _creatorJoins,
                onChanged: (value) => setState(() => _creatorJoins = value),
                title: const Text('Je participe à cette tontine'),
                subtitle: const Text('Désactivez si vous la gérez sans cotiser.'),
              ),
            ],
            const SizedBox(height: 14),
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
              child: _saving ? const ButtonSpinner() : const Text('Créer la tontine'),
            ),
            const SizedBox(height: 10),
            Text(
              'Vous pourrez inviter les membres juste après la création.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _TypeOption extends StatelessWidget {
  const _TypeOption({required this.type, required this.selected, required this.onTap});

  final TontineType type;
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
                Icon(type.icon, color: selected ? AppColors.leafDeep : AppColors.muted),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(type.label, style: theme.textTheme.titleMedium),
                      const SizedBox(height: 2),
                      Text(guideFor(type).summary, style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.muted)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                  color: selected ? AppColors.leaf : AppColors.line,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
