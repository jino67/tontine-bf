import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../content/tontine_guide.dart';
import '../../core/format.dart';
import '../../core/session/session_scope.dart';
import '../../core/widgets/ui.dart';
import '../../core/widgets/woven_band.dart';
import '../organizations/invite_sheet.dart';
import 'cycle_detail_screen.dart';
import 'draw_screen.dart';
import 'models.dart';
import 'status_style.dart';
import 'tontine_repository.dart';

class TontineDetailScreen extends StatefulWidget {
  const TontineDetailScreen({super.key, required this.repository, required this.tontineId});

  final TontineRepository repository;
  final int tontineId;

  @override
  State<TontineDetailScreen> createState() => _TontineDetailScreenState();
}

class _Detail {
  const _Detail(this.tontine, this.cycles);

  final Tontine tontine;
  final List<Cycle> cycles;
}

class _TontineDetailScreenState extends State<TontineDetailScreen> {
  late Future<_Detail> _future;
  bool _starting = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
    widget.repository.revision.addListener(_refresh);
  }

  @override
  void dispose() {
    widget.repository.revision.removeListener(_refresh);
    super.dispose();
  }

  Future<_Detail> _load() async {
    final tontine = await widget.repository.get(widget.tontineId);
    final cycles = tontine.isDraft ? const <Cycle>[] : await widget.repository.cycles(widget.tontineId);
    return _Detail(tontine, cycles);
  }

  Future<void> _refresh() async {
    final future = _load();
    setState(() => _future = future);
    try {
      await future;
    } catch (_) {
      // L'erreur est affichée à l'écran.
    }
  }

  Future<void> _start(Tontine tontine) async {
    final confirmed = await confirmAction(
      context,
      title: 'Démarrer la tontine ?',
      message: tontine.type.hasBeneficiaries
          ? 'Les inscriptions seront fermées. ${tontine.totalShares} tours seront créés, un par part, '
              'et les cotisations de chaque membre seront calculées.'
          : 'Les inscriptions seront fermées. ${tontine.cyclesCount} échéances seront créées '
              'et les cotisations de chaque membre seront calculées.',
      confirmLabel: 'Démarrer',
    );
    if (!confirmed || !mounted) return;

    setState(() => _starting = true);
    try {
      await widget.repository.start(tontine.id);
      if (mounted) showDone(context, 'Tontine démarrée');
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    final organization = session.currentOrganization!;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(),
      body: FutureBuilder<_Detail>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.hasError && !snapshot.hasData) return ErrorView(error: snapshot.error!, onRetry: _refresh);
          if (!snapshot.hasData) return const LoadingView();

          final tontine = snapshot.requireData.tontine;
          final cycles = snapshot.requireData.cycles;
          final canManage = organization.role.canManage;

          void invite() => showInviteSheet(
                context,
                organization: organization,
                tontineId: tontine.id,
                tontineName: tontine.name,
              );

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 40),
              children: [
                _Header(tontine: tontine),
                if (tontine.isDraft)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _RegistrationPanel(
                      tontine: tontine,
                      canManage: canManage,
                      starting: _starting,
                      onInvite: invite,
                      onStart: () => _start(tontine),
                    ),
                  ),
                if (cycles.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _ProgressPanel(tontine: tontine, cycles: cycles),
                  ),
                if (tontine.isActive && tontine.type == TontineType.drawOrder)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    child: _DrawEntry(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => DrawScreen(repository: widget.repository, tontine: tontine)),
                      ),
                    ),
                  ),
                if (cycles.isNotEmpty) ...[
                  SectionTitle(tontine.type.hasBeneficiaries ? 'Tours de passage' : 'Échéances'),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Card(
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        children: [
                          for (var i = 0; i < cycles.length; i++) ...[
                            if (i > 0) const Divider(indent: 64),
                            _CycleRow(
                              cycle: cycles[i],
                              tontine: tontine,
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => CycleDetailScreen(
                                    repository: widget.repository,
                                    tontineId: tontine.id,
                                    cycleId: cycles[i].id,
                                    tontineName: tontine.name,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
                SectionTitle(
                  'Membres (${tontine.members.length})',
                  trailing: canManage && tontine.isDraft ? TextButton(onPressed: invite, child: const Text('Inviter')) : null,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: tontine.members.isEmpty
                      ? Panel(
                          child: Text(
                            'Aucun membre inscrit pour le moment.',
                            style: theme.textTheme.bodyLarge?.copyWith(color: AppColors.muted),
                          ),
                        )
                      : Card(
                          clipBehavior: Clip.antiAlias,
                          child: Column(
                            children: [
                              for (var i = 0; i < tontine.members.length; i++) ...[
                                if (i > 0) const Divider(indent: 72),
                                _MemberRow(
                                  member: tontine.members[i],
                                  tontine: tontine,
                                  isMe: tontine.members[i].user?.id == session.user?.id,
                                ),
                              ],
                            ],
                          ),
                        ),
                ),
                if (tontine.type.hasBeneficiaries)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    child: Text(sharesExplanation, style: theme.textTheme.bodySmall),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.tontine});

  final Tontine tontine;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final personal = tontine.type == TontineType.personalSavings;
    final pot = tontine.potPerCycle;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StatusPill(label: tontine.status.label, tone: tontineStatusTone(tontine.status)),
              const SizedBox(width: 8),
              Flexible(child: Text(tontine.type.label, style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.muted))),
            ],
          ),
          const SizedBox(height: 12),
          Text(tontine.name, style: theme.textTheme.headlineMedium),
          if (tontine.goal != null) ...[
            const SizedBox(height: 6),
            Text(tontine.goal!, style: theme.textTheme.bodyLarge?.copyWith(color: AppColors.muted)),
          ],
          const SizedBox(height: 18),
          Wrap(
            spacing: 24,
            runSpacing: 14,
            children: [
              _Fact(label: personal ? 'Par versement' : 'Par part', value: fcfa(tontine.amount)),
              _Fact(label: 'Fréquence', value: tontine.frequency.label),
              _Fact(label: tontine.isDraft ? 'Premier tour' : 'Début', value: shortDate(tontine.startsOn)),
              if (!personal)
                _Fact(
                  label: 'Membres',
                  value: tontine.maxMembers != null ? '${tontine.memberCount} sur ${tontine.maxMembers}' : '${tontine.memberCount}',
                ),
              if (pot != null) _Fact(label: 'Reçu à chaque tour', value: fcfa(pot)),
            ],
          ),
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 2),
        Text(value, style: AppType.sans(size: 17, bold: true, tabular: true)),
      ],
    );
  }
}

class _RegistrationPanel extends StatelessWidget {
  const _RegistrationPanel({
    required this.tontine,
    required this.canManage,
    required this.starting,
    required this.onInvite,
    required this.onStart,
  });

  final Tontine tontine;
  final bool canManage;
  final bool starting;
  final VoidCallback onInvite;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final minimum = tontine.type == TontineType.personalSavings ? 1 : 2;
    final enough = tontine.memberCount >= minimum;

    return Panel(
      color: AppColors.goldSoft,
      borderColor: AppColors.goldSoft,
      radius: 20,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Inscriptions ouvertes', style: theme.textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(
            canManage
                ? 'Invitez les membres avec un code, puis démarrez la tontine. Au démarrage, les tours et les '
                    'cotisations sont calculés et les inscriptions se ferment.'
                : 'La tontine démarrera quand le responsable aura réuni tous les membres. Vos échéances apparaîtront alors ici.',
            style: theme.textTheme.bodyMedium,
          ),
          if (canManage) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onInvite,
                    icon: const Icon(Icons.person_add_alt_1_rounded),
                    label: const Text('Inviter'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: enough && !starting ? onStart : null,
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: Text(starting ? 'Démarrage…' : 'Démarrer'),
                  ),
                ),
              ],
            ),
            if (!enough) ...[
              const SizedBox(height: 8),
              Text('Il faut au moins $minimum membres pour démarrer.', style: theme.textTheme.bodySmall),
            ],
          ],
        ],
      ),
    );
  }
}

class _ProgressPanel extends StatelessWidget {
  const _ProgressPanel({required this.tontine, required this.cycles});

  final Tontine tontine;
  final List<Cycle> cycles;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentIndex = cycles.indexWhere((cycle) => cycle.status != CycleStatus.settled);
    final settled = cycles.where((cycle) => cycle.status == CycleStatus.settled).length;
    final due = cycles.fold<int>(0, (sum, cycle) => sum + cycle.amountDueTotal);
    final paid = cycles.fold<int>(0, (sum, cycle) => sum + cycle.amountPaidTotal);
    final unit = tontine.type.hasBeneficiaries ? 'tours' : 'échéances';

    return Panel(
      radius: 24,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(tontine.type.hasBeneficiaries ? 'Tours réglés' : 'Échéances réglées', style: theme.textTheme.titleMedium)),
              Text('$settled sur ${cycles.length}', style: AppType.sans(bold: true, tabular: true)),
            ],
          ),
          const SizedBox(height: 14),
          WovenBand(
            height: 22,
            semanticLabel: '$settled $unit réglés sur ${cycles.length}',
            segments: [
              for (var i = 0; i < cycles.length; i++) WeaveSegment(fill: cycles[i].paidRatio, highlight: i == currentIndex),
            ],
          ),
          const SizedBox(height: 8),
          Text('Chaque case est un tour. Le liseré doré marque le tour en cours.', style: theme.textTheme.bodySmall),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.end,
            children: [
              Money(paid, style: theme.textTheme.headlineSmall),
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text('encaissés sur ${fcfa(due)}', style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.muted)),
              ),
            ],
          ),
          if (currentIndex >= 0) ...[
            const SizedBox(height: 6),
            Text(
              'Tour en cours : n°${cycles[currentIndex].number}, échéance le ${shortDate(cycles[currentIndex].dueOn)}',
              style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.muted),
            ),
          ],
        ],
      ),
    );
  }
}

class _DrawEntry extends StatelessWidget {
  const _DrawEntry({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.indigoSoft,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.casino_outlined, color: AppColors.indigo),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Tirage de l’ordre de passage', style: AppType.sans(bold: true, color: AppColors.indigo)),
                    Text(
                      'Lancer, révéler et vérifier le tirage',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.indigo),
            ],
          ),
        ),
      ),
    );
  }
}

class _CycleRow extends StatelessWidget {
  const _CycleRow({required this.cycle, required this.tontine, required this.onTap});

  final Cycle cycle;
  final Tontine tontine;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final badge = cycleBadge(cycle);
    final colors = toneColors(badge.tone);
    final subtitle = cycle.beneficiary != null
        ? 'Pour ${cycle.beneficiary!.displayName}'
        : tontine.type == TontineType.drawOrder
            ? 'Bénéficiaire désigné par le tirage'
            : '${fcfa(cycle.amountPaidTotal)} sur ${fcfa(cycle.amountDueTotal)}';

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: colors.background, shape: BoxShape.circle),
              child: Text('${cycle.number}', style: AppType.sans(size: 15, bold: true, color: colors.foreground, tabular: true)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(capitalize(dayAndMonth(cycle.dueOn)), style: theme.textTheme.titleSmall),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            StatusPill(label: badge.label, tone: badge.tone),
          ],
        ),
      ),
    );
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({required this.member, required this.tontine, required this.isMe});

  final TontineMember member;
  final Tontine tontine;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final details = [
      countLabel(member.shares, 'part', 'parts'),
      if (member.position != null && tontine.type == TontineType.rotative) 'passage n°${member.position}',
    ].join(', ');

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: MemberAvatar(name: member.user?.name),
      title: Text(isMe ? '${member.displayName} (vous)' : member.displayName),
      subtitle: Text(details),
    );
  }
}
