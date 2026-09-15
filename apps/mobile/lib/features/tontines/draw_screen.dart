import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/format.dart';
import '../../core/session/session_scope.dart';
import '../../core/widgets/brand.dart';
import '../../core/widgets/picker_sheet.dart';
import '../../core/widgets/ui.dart';
import '../../core/widgets/verification.dart';
import 'draw_verifier.dart';
import 'models.dart';
import 'tontine_repository.dart';

/// Tirage vérifiable de l'ordre de passage, avec les tours éventuellement attribués par le responsable.
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

  /// Tours attribués avant le lancement : numéro de tour, puis membre.
  final _designations = <int, TontineMember>{};

  int get _cyclesCount => widget.tontine.totalShares;

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

  Future<void> _addDesignation() async {
    final freeCycles = [for (var cycle = 1; cycle <= _cyclesCount; cycle++) if (!_designations.containsKey(cycle)) cycle];
    final cycle = await showPickerSheet<int>(
      context,
      title: 'Quel tour attribuer ?',
      items: freeCycles,
      label: (cycle) => 'Tour $cycle',
      emptyMessage: 'Tous les tours sont déjà attribués.',
    );
    if (cycle == null || !mounted) return;

    final used = <int, int>{};
    for (final member in _designations.values) {
      used[member.id] = (used[member.id] ?? 0) + 1;
    }
    final member = await showPickerSheet<TontineMember>(
      context,
      title: 'Tour $cycle pour qui ?',
      items: [for (final member in widget.tontine.members) if ((used[member.id] ?? 0) < member.shares) member],
      label: (member) => member.displayName,
      subtitle: (member) => countLabel(member.shares - (used[member.id] ?? 0), 'part sans tour', 'parts sans tour'),
      leading: (member) => MemberAvatar(name: member.user?.name),
      emptyMessage: 'Chaque part a déjà un tour attribué.',
    );
    if (member != null) setState(() => _designations[cycle] = member);
  }

  Future<void> _commit() async {
    final assigned = _designations.length;
    final confirmed = await confirmAction(
      context,
      title: 'Lancer le tirage ?',
      message: '${assigned > 0 ? 'Les ${countLabel(assigned, 'tour attribué', 'tours attribués')} et l’empreinte seront publiés tout de suite, '
              'visibles par tous les membres. ' : 'L’empreinte sera publiée tout de suite. '}'
          'Le tirage pourra être révélé à partir du ${dateAndTime(_revealAfter)}. Rien ne pourra plus être changé.',
      confirmLabel: 'Lancer',
    );
    if (!confirmed || !mounted) return;
    await _run(
      () => widget.repository.commitDraw(
        widget.tontine.id,
        _revealAfter,
        designations: {for (final entry in _designations.entries) entry.key: entry.value.id},
      ),
      done: 'Tirage lancé, empreinte publiée',
    );
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
                      if (_draw == null) ..._notStarted(canManage),
                      if (_draw != null && !_draw!.isRevealed) ..._committed(_draw!),
                      if (_draw != null && _draw!.isRevealed) ..._revealed(_draw!),
                    ],
                  ),
                ),
    );
  }

  List<Widget> _notStarted(bool canManage) {
    final theme = Theme.of(context);
    if (!canManage) {
      return [
        Panel(
          child: Text(
            'Le responsable n’a pas encore lancé le tirage. Vous pourrez le révéler et le vérifier ici dès la date annoncée.',
            style: theme.textTheme.bodyLarge,
          ),
        ),
      ];
    }

    final cycles = _designations.keys.toList()..sort();
    final drawn = _cyclesCount - _designations.length;

    return [
      Panel(
        radius: 20,
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tours attribués (facultatif)', style: theme.textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(
              'Vous pouvez attribuer vous-même certains tours. Ils seront publiés à tous les membres dès le lancement '
              'et ne pourront plus changer. Les autres tours seront tirés au sort.',
              style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.muted),
            ),
            if (cycles.isNotEmpty) ...[
              const SizedBox(height: 12),
              for (final cycle in cycles)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: _CycleBadge(number: cycle, designated: true),
                  title: Text(_designations[cycle]!.displayName),
                  subtitle: Text('Tour $cycle'),
                  trailing: IconButton(
                    tooltip: 'Retirer',
                    onPressed: () => setState(() => _designations.remove(cycle)),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ),
            ],
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _designations.length < _cyclesCount ? _addDesignation : null,
              icon: const Icon(Icons.push_pin_outlined),
              label: const Text('Attribuer un tour'),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      Panel(
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
            RevealDateField(value: _revealAfter, onChanged: (value) => setState(() => _revealAfter = value)),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _busy ? null : _commit,
                style: FilledButton.styleFrom(backgroundColor: AppColors.indigo),
                child: _busy ? const ButtonSpinner() : Text('Lancer le tirage (${countLabel(drawn, 'tour tiré', 'tours tirés')})'),
              ),
            ),
          ],
        ),
      ),
    ];
  }

  List<Widget> _committed(Draw draw) {
    final theme = Theme.of(context);
    return [
      DrawSteps(current: draw.canReveal ? 1 : 0),
      const SizedBox(height: 16),
      Fingerprint(hash: draw.seedHash),
      const SizedBox(height: 12),
      LabeledValue(label: 'Révélation possible', value: dateAndTime(draw.revealAfter), icon: Icons.schedule_rounded),
      LabeledValue(label: 'Tours tirés au sort', value: '${draw.slots.length}', icon: Icons.confirmation_number_outlined),
      if (draw.designations.isNotEmpty) ...[
        const SectionTitle('Tours attribués par le responsable', padding: EdgeInsets.fromLTRB(0, 20, 0, 10)),
        _DesignationsCard(draw: draw, members: _membersById),
      ],
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
        Text(revealHint(context, draw.revealAfter), style: theme.textTheme.bodySmall),
      ],
    ];
  }

  Map<int, TontineMember> get _membersById => {for (final member in widget.tontine.members) member.id: member};

  List<Widget> _revealed(Draw draw) {
    final theme = Theme.of(context);
    final members = _membersById;
    final designated = draw.designatedCycles;

    return [
      VerificationBanner(
        verified: DrawVerifier.verify(draw),
        successMessage: 'La graine révélée correspond à l’empreinte publiée, et l’ordre a été recalculé ici sans faire confiance au serveur.',
      ),
      const SectionTitle('Ordre de passage', padding: EdgeInsets.fromLTRB(0, 28, 0, 10)),
      Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            for (var i = 0; i < draw.order.length; i++) ...[
              if (i > 0) const Divider(indent: 64),
              _OrderRow(
                position: i + 1,
                slot: draw.order[i],
                member: members[Draw.memberIdOf(draw.order[i])],
                designated: designated.contains(i + 1),
              ),
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
            SelectableText(draw.seed ?? '', style: monoStyle),
            const SizedBox(height: 10),
            Text('Empreinte publiée avant le tirage', style: theme.textTheme.bodySmall),
            SelectableText(draw.seedHash, style: monoStyle),
            const SizedBox(height: 10),
            Text(
              'Contrôle : sha256(graine) doit donner l’empreinte. Les parts tirées sont triées par sha256(graine + "|" + part), '
              'dans l’ordre croissant, puis placées dans les tours non attribués, du premier au dernier.',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    ];
  }
}

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
          'Les tours attribués par le responsable sont publiés à tous au lancement. Les autres dépendent d’une graine secrète '
          'dont l’empreinte est publiée en même temps : ensuite, personne ne peut plus changer le résultat.',
          style: theme.textTheme.bodyLarge?.copyWith(color: AppColors.muted),
        ),
      ],
    );
  }
}

class _CycleBadge extends StatelessWidget {
  const _CycleBadge({required this.number, required this.designated});

  final int number;
  final bool designated;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: designated ? AppColors.indigoSoft : AppColors.goldSoft, shape: BoxShape.circle),
      child: Text(
        '$number',
        style: AppType.sans(size: 15, bold: true, color: designated ? AppColors.indigo : AppColors.goldText, tabular: true),
      ),
    );
  }
}

class _DesignationsCard extends StatelessWidget {
  const _DesignationsCard({required this.draw, required this.members});

  final Draw draw;
  final Map<int, TontineMember> members;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < draw.designations.length; i++) ...[
            if (i > 0) const Divider(indent: 64),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
              leading: _CycleBadge(number: draw.designations[i].cycle, designated: true),
              title: Text(members[draw.designations[i].memberId]?.displayName ?? 'Membre retiré'),
              subtitle: Text('Tour ${draw.designations[i].cycle}, attribué par le responsable'),
            ),
          ],
        ],
      ),
    );
  }
}

class _OrderRow extends StatelessWidget {
  const _OrderRow({required this.position, required this.slot, required this.member, required this.designated});

  final int position;
  final String slot;
  final TontineMember? member;
  final bool designated;

  @override
  Widget build(BuildContext context) {
    final part = int.tryParse(slot.split('#').last) ?? 1;
    final shares = member?.shares ?? 1;
    final how = designated ? 'attribué par le responsable' : 'tiré au sort';

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: _CycleBadge(number: position, designated: designated),
      title: Text(member?.displayName ?? 'Membre retiré'),
      subtitle: Text(shares > 1 ? 'Tour $position, ${ordinal(part)} part, $how' : 'Tour $position, $how'),
    );
  }
}
