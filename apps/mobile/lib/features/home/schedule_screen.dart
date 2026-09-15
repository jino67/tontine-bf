import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app/theme.dart';
import '../../core/format.dart';
import '../../core/widgets/brand.dart';
import '../../core/widgets/ui.dart';
import '../tontines/cycle_detail_screen.dart';
import '../tontines/models.dart';
import '../tontines/tontine_repository.dart';

/// Échéancier personnel du membre dans l'organisation courante.
class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key, required this.repository});

  final TontineRepository repository;

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  late Future<List<MyContribution>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.repository.myContributions();
    widget.repository.revision.addListener(_refresh);
  }

  @override
  void dispose() {
    widget.repository.revision.removeListener(_refresh);
    super.dispose();
  }

  Future<void> _refresh() async {
    final future = widget.repository.myContributions();
    setState(() => _future = future);
    try {
      await future;
    } catch (_) {
      // L'erreur est affichée à l'écran.
    }
  }

  Future<void> _confirm(MyContribution item) async {
    final confirmed = await confirmAction(
      context,
      title: 'Confirmer votre paiement ?',
      message: 'Vous confirmez avoir versé ${fcfa(item.contribution.amountPaid)} pour le tour ${item.cycleNumber} '
          'de ${item.tontineName}. Cette cotisation ne pourra plus être modifiée.',
      confirmLabel: 'Confirmer',
    );
    if (!confirmed || !mounted) return;

    try {
      await widget.repository.confirmPayment(item.tontineId, item.contribution);
      if (mounted) showDone(context, 'Paiement confirmé');
    } catch (error) {
      if (mounted) showError(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mes échéances')),
      body: FutureBuilder<List<MyContribution>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.hasError && !snapshot.hasData) return ErrorView(error: snapshot.error!, onRetry: _refresh);
          if (!snapshot.hasData) return const LoadingView();

          final items = snapshot.requireData;
          if (items.isEmpty) {
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 60),
                  MessageView(
                    icon: Icons.event_available_rounded,
                    title: 'Aucune échéance',
                    message: 'Vos cotisations apparaîtront ici dès qu’une tontine à laquelle vous participez aura démarré.',
                  ),
                ],
              ),
            );
          }

          final late = <MyContribution>[];
          final toConfirm = <MyContribution>[];
          final upcoming = <MyContribution>[];
          final history = <MyContribution>[];
          for (final item in items) {
            switch (item.contribution.status) {
              case ContributionStatus.confirmed:
                history.add(item);
              case ContributionStatus.recorded:
                toConfirm.add(item);
              case ContributionStatus.pending when item.isLate:
                late.add(item);
              case ContributionStatus.pending:
                upcoming.add(item);
            }
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 32),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      StatusPill(label: '${upcoming.length} à venir'),
                      if (late.isNotEmpty) StatusPill(label: '${late.length} en retard', tone: Tone.danger),
                      if (toConfirm.isNotEmpty) StatusPill(label: '${toConfirm.length} à confirmer', tone: Tone.gold),
                      StatusPill(label: countLabel(history.length, 'confirmée', 'confirmées'), tone: Tone.positive),
                    ],
                  ),
                ),
                ..._section('À confirmer', toConfirm),
                ..._section('En retard', late),
                ..._section('À venir', upcoming),
                if (history.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Card(
                      clipBehavior: Clip.antiAlias,
                      child: ExpansionTile(
                        title: Text('Historique (${history.length})', style: Theme.of(context).textTheme.titleMedium),
                        children: _rows(history.reversed.toList()),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  List<Widget> _section(String title, List<MyContribution> items) {
    if (items.isEmpty) return const [];
    return [
      SectionTitle(title),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Card(clipBehavior: Clip.antiAlias, child: Column(children: _rows(items))),
      ),
    ];
  }

  List<Widget> _rows(List<MyContribution> items) => [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const Divider(indent: 82),
          _ScheduleRow(
            item: items[i],
            repository: widget.repository,
            onConfirm: items[i].contribution.status == ContributionStatus.recorded ? () => _confirm(items[i]) : null,
          ),
        ],
      ];
}

class _ScheduleRow extends StatelessWidget {
  const _ScheduleRow({required this.item, required this.repository, this.onConfirm});

  final MyContribution item;
  final TontineRepository repository;
  final VoidCallback? onConfirm;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final contribution = item.contribution;
    final pending = contribution.status == ContributionStatus.pending;
    final amount = pending ? contribution.amountDue - contribution.amountPaid : contribution.amountPaid;

    final tone = item.isLate && pending
        ? Tone.danger
        : item.isBeneficiary
            ? Tone.gold
            : Tone.positive;

    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CycleDetailScreen(
            repository: repository,
            tontineId: item.tontineId,
            cycleId: contribution.cycleId,
            tontineName: item.tontineName,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DateBlock(date: item.dueOn, tone: tone),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.tontineName, style: theme.textTheme.titleMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(
                    item.isBeneficiary ? 'Tour ${item.cycleNumber}, vous recevez la cagnotte' : 'Tour ${item.cycleNumber}',
                    style: theme.textTheme.bodyMedium?.copyWith(color: item.isBeneficiary ? AppColors.goldText : AppColors.muted),
                  ),
                  if (onConfirm != null) ...[
                    const SizedBox(height: 10),
                    FilledButton(onPressed: onConfirm, style: CompactButtons.filled, child: const Text('Confirmer mon paiement')),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Money(amount, style: theme.textTheme.titleMedium),
          ],
        ),
      ),
    );
  }
}

/// Date en pavé : le jour en grand, le mois en dessous.
class _DateBlock extends StatelessWidget {
  const _DateBlock({required this.date, required this.tone});

  final DateTime date;
  final Tone tone;

  @override
  Widget build(BuildContext context) {
    final colors = toneColors(tone);
    return Container(
      width: 52,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(color: colors.background, borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          Text(DateFormat('d', 'fr').format(date), style: AppType.serif(22, color: colors.foreground, height: 1)),
          const SizedBox(height: 2),
          Text(DateFormat('MMM', 'fr').format(date), style: AppType.sans(size: 12, bold: true, color: colors.foreground, height: 1.1)),
        ],
      ),
    );
  }
}
