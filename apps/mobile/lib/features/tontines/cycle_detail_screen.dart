import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/format.dart';
import '../../core/session/session_scope.dart';
import '../../core/widgets/brand.dart';
import '../../core/widgets/ui.dart';
import '../../core/widgets/woven_band.dart';
import '../payments/pay_online.dart';
import 'models.dart';
import 'record_payment_sheet.dart';
import 'status_style.dart';
import 'tontine_repository.dart';

class CycleDetailScreen extends StatefulWidget {
  const CycleDetailScreen({
    super.key,
    required this.repository,
    required this.tontineId,
    required this.cycleId,
    this.tontineName,
  });

  final TontineRepository repository;
  final int tontineId;
  final int cycleId;
  final String? tontineName;

  @override
  State<CycleDetailScreen> createState() => _CycleDetailScreenState();
}

class _CycleDetailScreenState extends State<CycleDetailScreen> {
  late Future<Cycle> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.repository.cycle(widget.tontineId, widget.cycleId);
    widget.repository.revision.addListener(_refresh);
  }

  @override
  void dispose() {
    widget.repository.revision.removeListener(_refresh);
    super.dispose();
  }

  Future<void> _refresh() async {
    final future = widget.repository.cycle(widget.tontineId, widget.cycleId);
    setState(() => _future = future);
    try {
      await future;
    } catch (_) {
      // L'erreur est affichée à l'écran.
    }
  }

  Future<void> _record(Contribution contribution) async {
    final saved = await showRecordPaymentSheet(
      context,
      repository: widget.repository,
      tontineId: widget.tontineId,
      contribution: contribution,
      memberName: contribution.member?.displayName ?? 'Ce membre',
    );
    if (saved == true && mounted) showDone(context, 'Paiement enregistré');
  }

  Future<void> _confirm(Cycle cycle, Contribution contribution) async {
    final confirmed = await confirmAction(
      context,
      title: 'Confirmer votre paiement ?',
      message: 'Vous confirmez avoir versé ${fcfa(contribution.amountPaid)} pour le tour ${cycle.number}. '
          'Cette cotisation ne pourra plus être modifiée.',
      confirmLabel: 'Confirmer',
    );
    if (!confirmed || !mounted) return;

    try {
      await widget.repository.confirmPayment(widget.tontineId, contribution);
      if (mounted) showDone(context, 'Paiement confirmé');
    } catch (error) {
      if (mounted) showError(context, error);
    }
  }

  Future<void> _payOnline(Contribution contribution) async {
    final paid = await payOnline(
      context,
      start: (payments) => payments.payContribution(widget.tontineId, contribution.cycleId, contribution.id),
    );
    if (paid) widget.repository.revision.value++;
  }

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    final canRecord = session.currentOrganization!.role.canRecordPayments;
    final myId = session.user?.id;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(widget.tontineName ?? 'Tour')),
      body: FutureBuilder<Cycle>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.hasError && !snapshot.hasData) return ErrorView(error: snapshot.error!, onRetry: _refresh);
          if (!snapshot.hasData) return const LoadingView();

          final cycle = snapshot.requireData;
          final late = isOverdue(cycle.dueOn);

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 40),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Tour ${cycle.number}', style: theme.textTheme.headlineMedium),
                      const SizedBox(height: 4),
                      Text(
                        capitalize('${dayAndMonth(cycle.dueOn)}, ${relativeDay(cycle.dueOn)}'),
                        style: theme.textTheme.bodyLarge?.copyWith(color: late ? AppColors.chili : AppColors.muted),
                      ),
                    ],
                  ),
                ),
                if (cycle.beneficiary != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    child: _BeneficiaryCard(cycle: cycle),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: _CollectionPanel(cycle: cycle, late: late),
                ),
                const SectionTitle('Cotisations'),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Card(
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        for (var i = 0; i < cycle.contributions.length; i++) ...[
                          if (i > 0) const Divider(indent: 68),
                          _ContributionRow(
                            contribution: cycle.contributions[i],
                            late: late,
                            isMine: cycle.contributions[i].member?.user?.id == myId,
                            canRecord: canRecord,
                            onRecord: () => _record(cycle.contributions[i]),
                            onConfirm: () => _confirm(cycle, cycle.contributions[i]),
                            onPayOnline: () => _payOnline(cycle.contributions[i]),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                  child: Text(
                    'Le trésorier enregistre chaque paiement reçu, puis le membre concerné le confirme. '
                    'Une cotisation confirmée est verrouillée.',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _BeneficiaryCard extends StatelessWidget {
  const _BeneficiaryCard({required this.cycle});

  final Cycle cycle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = cycle.beneficiary!.displayName;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.goldSoft,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          MemberAvatar(name: cycle.beneficiary!.user?.name, size: 52, tone: Tone.positive),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Reçoit la cagnotte de ce tour', style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.goldText)),
                Text(name, style: theme.textTheme.titleLarge),
                const SizedBox(height: 4),
                Money(cycle.amountDueTotal, style: AppType.sans(size: 18, bold: true, color: AppColors.goldText)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CollectionPanel extends StatelessWidget {
  const _CollectionPanel({required this.cycle, required this.late});

  final Cycle cycle;
  final bool late;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final contributions = cycle.contributions;
    final confirmed = contributions.where((c) => c.status == ContributionStatus.confirmed).length;
    final recorded = contributions.where((c) => c.status == ContributionStatus.recorded).length;
    final pending = contributions.where((c) => c.status == ContributionStatus.pending).length;

    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.end,
            children: [
              Money(cycle.amountPaidTotal, style: theme.textTheme.headlineSmall),
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  'encaissés sur ${fcfa(cycle.amountDueTotal)}',
                  style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.muted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          WovenBand(
            semanticLabel: '$confirmed cotisations confirmées sur ${contributions.length}',
            segments: [
              for (final contribution in contributions)
                WeaveSegment(
                  fill: contribution.amountDue == 0 ? 0 : contribution.amountPaid / contribution.amountDue,
                  color: contribution.status == ContributionStatus.confirmed ? AppColors.leaf : AppColors.gold,
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text('Une case par membre : vert si confirmée, or si à confirmer.', style: theme.textTheme.bodySmall),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              StatusPill(label: countLabel(confirmed, 'confirmée', 'confirmées'), tone: Tone.positive),
              if (recorded > 0) StatusPill(label: '$recorded à confirmer', tone: Tone.gold),
              if (pending > 0) StatusPill(label: late ? '$pending en retard' : '$pending à payer', tone: late ? Tone.danger : Tone.neutral),
            ],
          ),
        ],
      ),
    );
  }
}

class _ContributionRow extends StatelessWidget {
  const _ContributionRow({
    required this.contribution,
    required this.late,
    required this.isMine,
    required this.canRecord,
    required this.onRecord,
    required this.onConfirm,
    required this.onPayOnline,
  });

  final Contribution contribution;
  final bool late;
  final bool isMine;
  final bool canRecord;
  final VoidCallback onRecord;
  final VoidCallback onConfirm;
  final VoidCallback onPayOnline;

  String get _details {
    if (contribution.amountPaid == 0) return 'Doit ${fcfa(contribution.amountDue)}';
    final method = contribution.method;
    final how = method == null
        ? ''
        : method == PaymentMethod.cash
            ? ' en espèces'
            : ' par ${method.label}';
    final rest = contribution.isFullyPaid ? '' : ', reste ${fcfa(contribution.amountDue - contribution.amountPaid)}';
    final reference = contribution.reference == null ? '' : '\nRéférence ${contribution.reference}';
    return '${fcfa(contribution.amountPaid)}$how$rest$reference';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = contribution.member?.displayName ?? 'Membre';
    final badge = contributionBadge(contribution, late: late);
    final showRecord = canRecord && contribution.status != ContributionStatus.confirmed;
    final showConfirm = isMine && contribution.status == ContributionStatus.recorded;
    final showPay = isMine && contribution.status != ContributionStatus.confirmed && !contribution.isFullyPaid;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MemberAvatar(name: contribution.member?.user?.name),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(isMine ? '$name (vous)' : name, style: theme.textTheme.titleSmall),
                    const SizedBox(height: 2),
                    Text(_details, style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.muted)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              StatusPill(label: badge.label, tone: badge.tone),
            ],
          ),
          if (showRecord || showConfirm || showPay)
            Padding(
              padding: const EdgeInsets.only(left: 52, top: 10),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (showRecord)
                    OutlinedButton(
                      onPressed: onRecord,
                      style: CompactButtons.outlined,
                      child: Text(contribution.amountPaid > 0 ? 'Modifier' : 'Enregistrer le paiement'),
                    ),
                  if (showConfirm)
                    FilledButton(onPressed: onConfirm, style: CompactButtons.filled, child: const Text('Confirmer mon paiement')),
                  if (showPay)
                    FilledButton.icon(
                      onPressed: onPayOnline,
                      style: CompactButtons.filled,
                      icon: const Icon(Icons.phone_iphone_rounded, size: 18),
                      label: Text('Payer ${fcfa(contribution.amountDue - contribution.amountPaid)} en ligne'),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
