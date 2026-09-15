import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/format.dart';
import '../../core/session/session_scope.dart';
import '../../core/widgets/brand.dart';
import '../../core/widgets/ui.dart';
import 'draw_verifier.dart';
import 'models.dart';
import 'tontine_repository.dart';

/// Tirage vérifiable de l'ordre de passage.
class DrawScreen extends StatefulWidget {
  const DrawScreen({super.key, required this.repository, required this.tontine});

  final TontineRepository repository;

  /// Avec ses membres chargés, pour afficher les noms dans l'ordre tiré.
  final Tontine tontine;

  @override
  State<DrawScreen> createState() => _DrawScreenState();
}

class _DrawScreenState extends State<DrawScreen> {
  Draw? _draw;
  Object? _error;
  bool _loading = true;
  bool _busy = false;
  late DateTime _revealAfter;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _revealAfter = DateTime(now.year, now.month, now.day, now.hour).add(const Duration(days: 1));
    _fetch();
    // Réactive le bouton de révélation dès que la date est passée, sans recharger l'écran.
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted && _draw != null && !_draw!.isRevealed) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _fetch() async {
    try {
      final draw = await widget.repository.draw(widget.tontine.id);
      if (!mounted) return;
      setState(() {
        _draw = draw;
        _error = null;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  Future<void> _retry() async {
    setState(() => _loading = true);
    await _fetch();
  }

  Future<void> _pickRevealDate() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final date = await showDatePicker(
      context: context,
      initialDate: _revealAfter,
      firstDate: today,
      lastDate: today.add(const Duration(days: 60)),
      helpText: 'Date de révélation',
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_revealAfter),
      helpText: 'Heure de révélation',
    );
    if (time == null) return;

    var chosen = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    if (chosen.isBefore(DateTime.now())) chosen = DateTime.now().add(const Duration(minutes: 5));
    setState(() => _revealAfter = chosen);
  }

  Future<void> _commit() async {
    final confirmed = await confirmAction(
      context,
      title: 'Lancer le tirage ?',
      message: 'L’empreinte sera publiée tout de suite. Le tirage pourra être révélé à partir du '
          '${dateAndTime(_revealAfter)}. Cette date ne pourra plus être changée.',
      confirmLabel: 'Lancer',
    );
    if (!confirmed || !mounted) return;
    await _run(() => widget.repository.commitDraw(widget.tontine.id, _revealAfter), done: 'Tirage lancé, empreinte publiée');
  }

  Future<void> _reveal() => _run(() => widget.repository.revealDraw(widget.tontine.id), done: 'Tirage révélé');

  Future<void> _run(Future<Draw> Function() action, {required String done}) async {
    setState(() => _busy = true);
    try {
      final draw = await action();
      if (!mounted) return;
      setState(() => _draw = draw);
      showDone(context, done);
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canManage = SessionScope.of(context).currentOrganization!.role.canManage;

    return Scaffold(
      appBar: AppBar(title: const Text('Tirage au sort')),
      body: _loading
          ? const LoadingView()
          : _error != null
              ? ErrorView(error: _error!, onRetry: _retry)
              : RefreshIndicator(
                  onRefresh: _fetch,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                    children: [
                      const _Intro(),
                      const SizedBox(height: 20),
                      if (_draw == null) _notStarted(canManage),
                      if (_draw != null && !_draw!.isRevealed) _committed(_draw!),
                      if (_draw != null && _draw!.isRevealed) ..._revealed(_draw!),
                    ],
                  ),
                ),
    );
  }

  Widget _notStarted(bool canManage) {
    final theme = Theme.of(context);
    if (!canManage) {
      return Panel(
        child: Text(
          'Le responsable n’a pas encore lancé le tirage. Vous pourrez le révéler et le vérifier ici dès la date annoncée.',
          style: theme.textTheme.bodyLarge,
        ),
      );
    }

    return Panel(
      radius: 20,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Choisir la date de révélation', style: theme.textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(
            'Annoncez cette date aux membres : n’importe lequel d’entre eux pourra alors révéler et vérifier le résultat.',
            style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.muted),
          ),
          const SizedBox(height: 16),
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: _pickRevealDate,
            child: InputDecorator(
              decoration: const InputDecoration(labelText: 'Révélation possible à partir du', suffixIcon: Icon(Icons.schedule_rounded)),
              child: Text(dateAndTime(_revealAfter), style: theme.textTheme.bodyLarge),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _busy ? null : _commit,
              style: FilledButton.styleFrom(backgroundColor: AppColors.indigo),
              child: _busy ? const ButtonSpinner() : Text('Lancer le tirage (${countLabel(widget.tontine.totalShares, 'part', 'parts')})'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _committed(Draw draw) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Steps(current: draw.canReveal ? 1 : 0),
        const SizedBox(height: 16),
        _Fingerprint(hash: draw.seedHash),
        const SizedBox(height: 12),
        LabeledValue(label: 'Révélation possible', value: dateAndTime(draw.revealAfter), icon: Icons.schedule_rounded),
        LabeledValue(label: 'Parts tirées', value: '${draw.slots.length}', icon: Icons.confirmation_number_outlined),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: draw.canReveal && !_busy ? _reveal : null,
            style: FilledButton.styleFrom(backgroundColor: AppColors.indigo),
            child: _busy ? const ButtonSpinner() : const Text('Révéler le tirage'),
          ),
        ),
        if (!draw.canReveal) ...[
          const SizedBox(height: 8),
          Text(
            'Le bouton s’activera ${relativeDay(draw.revealAfter.toLocal())} à ${TimeOfDay.fromDateTime(draw.revealAfter.toLocal()).format(context)}.',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ],
    );
  }

  List<Widget> _revealed(Draw draw) {
    final theme = Theme.of(context);
    final verified = DrawVerifier.verify(draw);
    final members = {for (final member in widget.tontine.members) member.id: member};

    return [
      Panel(
        color: verified ? AppColors.leafSoft : AppColors.chiliSoft,
        borderColor: verified ? AppColors.leafSoft : AppColors.chiliSoft,
        radius: 20,
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(verified ? Icons.verified_rounded : Icons.gpp_bad_rounded, color: verified ? AppColors.leafDeep : AppColors.chili, size: 30),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(verified ? 'Tirage vérifié sur ce téléphone' : 'Vérification échouée', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 4),
                  Text(
                    verified
                        ? 'La graine révélée correspond à l’empreinte publiée, et l’ordre a été recalculé ici sans faire confiance au serveur.'
                        : 'Le résultat ne correspond pas à l’empreinte publiée. Signalez-le à votre organisation.',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      const SectionTitle('Ordre de passage', padding: EdgeInsets.fromLTRB(0, 28, 0, 10)),
      Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            for (var i = 0; i < draw.order.length; i++) ...[
              if (i > 0) const Divider(indent: 64),
              _OrderRow(position: i + 1, slot: draw.order[i], member: members[Draw.memberIdOf(draw.order[i])]),
            ],
          ],
        ),
      ),
      const SizedBox(height: 16),
      Card(
        clipBehavior: Clip.antiAlias,
        child: ExpansionTile(
          title: Text('Détails de vérification', style: theme.textTheme.titleSmall),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Graine révélée', style: theme.textTheme.bodySmall),
            SelectableText(draw.seed ?? '', style: _mono),
            const SizedBox(height: 10),
            Text('Empreinte publiée avant le tirage', style: theme.textTheme.bodySmall),
            SelectableText(draw.seedHash, style: _mono),
            const SizedBox(height: 10),
            Text(
              'Contrôle : sha256(graine) doit donner l’empreinte. Les parts sont ensuite triées par sha256(graine + "|" + part), '
              'dans l’ordre croissant.',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    ];
  }
}

const _mono = TextStyle(fontFamily: 'monospace', fontSize: 13, height: 1.5, color: AppColors.ink);

class _Intro extends StatelessWidget {
  const _Intro();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: const BoxDecoration(color: AppColors.indigoSoft, shape: BoxShape.circle),
          child: const Icon(Icons.casino_outlined, color: AppColors.indigo, size: 28),
        ),
        const SizedBox(height: 14),
        Text('Ordre de passage', style: theme.textTheme.headlineMedium),
        const SizedBox(height: 8),
        Text(
          'Le résultat dépend d’une graine secrète dont l’empreinte est publiée avant le tirage. '
          'Une fois l’empreinte publiée, personne ne peut plus changer le résultat.',
          style: theme.textTheme.bodyLarge?.copyWith(color: AppColors.muted),
        ),
      ],
    );
  }
}

/// Les trois étapes du tirage, dans l'ordre où elles se déroulent.
class _Steps extends StatelessWidget {
  const _Steps({required this.current});

  final int current;

  static const _labels = ['Empreinte publiée', 'Révélation après la date annoncée', 'Vérification sur chaque téléphone'];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < _labels.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: i <= current ? AppColors.indigo : AppColors.indigoSoft,
                    shape: BoxShape.circle,
                  ),
                  child: i < current || i == 0
                      ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
                      : Text('${i + 1}', style: AppType.sans(size: 13, bold: true, color: i <= current ? Colors.white : AppColors.indigo)),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(_labels[i], style: AppType.sans(bold: i <= current))),
              ],
            ),
          ),
      ],
    );
  }
}

class _Fingerprint extends StatelessWidget {
  const _Fingerprint({required this.hash});

  final String hash;

  @override
  Widget build(BuildContext context) {
    final groups = [for (var i = 0; i < hash.length; i += 8) hash.substring(i, (i + 8).clamp(0, hash.length))];
    return Panel(
      color: AppColors.indigoSoft,
      borderColor: AppColors.indigoSoft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Empreinte publiée', style: AppType.sans(bold: true, color: AppColors.indigo)),
          const SizedBox(height: 8),
          SelectableText(groups.join(' '), style: _mono.copyWith(fontSize: 15, color: AppColors.indigo)),
        ],
      ),
    );
  }
}

class _OrderRow extends StatelessWidget {
  const _OrderRow({required this.position, required this.slot, required this.member});

  final int position;
  final String slot;
  final TontineMember? member;

  @override
  Widget build(BuildContext context) {
    final part = int.tryParse(slot.split('#').last) ?? 1;
    final shares = member?.shares ?? 1;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: const BoxDecoration(color: AppColors.goldSoft, shape: BoxShape.circle),
        child: Text('$position', style: AppType.sans(size: 15, bold: true, color: AppColors.goldText, tabular: true)),
      ),
      title: Text(member?.displayName ?? 'Membre retiré'),
      subtitle: Text(shares > 1 ? 'Tour $position, ${part == 1 ? '1re' : '${part}e'} part' : 'Tour $position'),
    );
  }
}
