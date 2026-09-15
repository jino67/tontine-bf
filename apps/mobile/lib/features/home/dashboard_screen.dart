import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../content/help.dart';
import '../../core/format.dart';
import '../../core/session/session_scope.dart';
import '../../core/widgets/ui.dart';
import '../../core/widgets/woven_band.dart';
import '../profile/help_screen.dart';
import '../tontines/create_tontine_screen.dart';
import '../tontines/models.dart';
import '../tontines/tontine_repository.dart';
import '../tontines/tontine_tile.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, required this.repository, required this.onOpenTab});

  final TontineRepository repository;
  final ValueChanged<int> onOpenTab;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardData {
  const _DashboardData(this.tontines, this.contributions);

  final List<Tontine> tontines;
  final List<MyContribution> contributions;
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<_DashboardData> _future;

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

  Future<_DashboardData> _load() async {
    // Une requête après l'autre : le serveur de développement les traite une par une.
    final contributions = await widget.repository.myContributions();
    final tontines = await widget.repository.list();
    return _DashboardData(tontines, contributions);
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

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    final organization = session.currentOrganization!;

    return Scaffold(
      body: SafeArea(
        child: FutureBuilder<_DashboardData>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.hasError && !snapshot.hasData) return ErrorView(error: snapshot.error!, onRetry: _refresh);
            if (!snapshot.hasData) return const LoadingView();

            final data = snapshot.requireData;
            final lateCount = data.contributions.where((item) => item.isLate).length;

            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 32),
                children: [
                  _Header(
                    organizationName: organization.name,
                    userName: session.user?.name,
                    onProfile: () => widget.onOpenTab(3),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _NextPaymentHero(contributions: data.contributions, onSchedule: () => widget.onOpenTab(2)),
                  ),
                  if (lateCount > 1)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                      child: _LateNotice(count: lateCount, onTap: () => widget.onOpenTab(2)),
                    ),
                  if (organization.role.canRecordPayments) _TreasurerSummary(tontines: data.tontines),
                  SectionTitle(
                    'Mes tontines',
                    trailing: data.tontines.length > 3
                        ? TextButton(onPressed: () => widget.onOpenTab(1), child: const Text('Tout voir'))
                        : null,
                  ),
                  if (data.tontines.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _EmptyTontines(canManage: organization.role.canManage, repository: widget.repository),
                    )
                  else
                    for (final tontine in data.tontines.take(3))
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                        child: TontineTile(tontine: tontine, repository: widget.repository),
                      ),
                  const SectionTitle('Bon à savoir'),
                  const Padding(padding: EdgeInsets.symmetric(horizontal: 20), child: _TipOfTheDay()),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.organizationName, required this.userName, required this.onProfile});

  final String organizationName;
  final String? userName;
  final VoidCallback onProfile;

  String get _greeting {
    final hello = DateTime.now().hour >= 18 ? 'Bonsoir' : 'Bonjour';
    final firstName = (userName ?? '').trim().split(RegExp(r'\s+')).first;
    return firstName.isEmpty ? hello : '$hello $firstName';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 20),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  organizationName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.muted),
                ),
                const SizedBox(height: 2),
                Text(_greeting, style: theme.textTheme.headlineMedium),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Mon profil',
            padding: EdgeInsets.zero,
            onPressed: onProfile,
            icon: MemberAvatar(name: userName, size: 44, tone: Tone.gold),
          ),
        ],
      ),
    );
  }
}

/// Le premier bloc de l'accueil : ce que le membre doit payer ensuite, et quand il reçoit.
class _NextPaymentHero extends StatelessWidget {
  const _NextPaymentHero({required this.contributions, required this.onSchedule});

  final List<MyContribution> contributions;
  final VoidCallback onSchedule;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const soft = Color(0xC7FFFFFF);

    MyContribution? next;
    MyContribution? toReceive;
    final today = DateUtils.dateOnly(DateTime.now());
    for (final item in contributions) {
      if (next == null && !item.contribution.isFullyPaid) next = item;
      if (toReceive == null && item.isBeneficiary && !item.dueOn.isBefore(today)) toReceive = item;
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 10),
      decoration: BoxDecoration(color: AppColors.leafDeep, borderRadius: BorderRadius.circular(24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (next != null) ...[
            Row(
              children: [
                Expanded(child: Text('Ma prochaine cotisation', style: theme.textTheme.bodyMedium?.copyWith(color: soft))),
                if (next.isLate) const StatusPill(label: 'En retard', tone: Tone.danger),
              ],
            ),
            const SizedBox(height: 6),
            Money(
              next.contribution.amountDue - next.contribution.amountPaid,
              style: theme.textTheme.displaySmall?.copyWith(color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              capitalize('${relativeDay(next.dueOn)}, ${dayAndMonth(next.dueOn)}'),
              style: AppType.sans(size: 17, bold: true, color: Colors.white),
            ),
            Text('${next.tontineName}, tour ${next.cycleNumber}', style: theme.textTheme.bodyMedium?.copyWith(color: soft)),
          ] else if (contributions.isEmpty) ...[
            Text('Aucune cotisation prévue', style: theme.textTheme.headlineSmall?.copyWith(color: Colors.white)),
            const SizedBox(height: 8),
            Text(
              'Vos échéances apparaîtront ici dès qu’une tontine à laquelle vous participez aura démarré.',
              style: theme.textTheme.bodyMedium?.copyWith(color: soft),
            ),
          ] else ...[
            Row(
              children: [
                const Icon(Icons.verified_rounded, color: AppColors.gold),
                const SizedBox(width: 10),
                Text('Vous êtes à jour', style: theme.textTheme.headlineSmall?.copyWith(color: Colors.white)),
              ],
            ),
            const SizedBox(height: 8),
            Text('Toutes vos cotisations sont enregistrées.', style: theme.textTheme.bodyMedium?.copyWith(color: soft)),
          ],
          if (toReceive != null) ...[
            const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider(color: Color(0x33FFFFFF))),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.savings_rounded, color: AppColors.gold),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Vous recevez la cagnotte de ${toReceive.tontineName} au tour ${toReceive.cycleNumber}, '
                    '${relativeDay(toReceive.dueOn)}.',
                    style: theme.textTheme.bodyLarge?.copyWith(color: Colors.white),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 6),
          TextButton(
            onPressed: onSchedule,
            style: TextButton.styleFrom(foregroundColor: AppColors.gold, padding: EdgeInsets.zero),
            child: const Text('Voir mes échéances'),
          ),
        ],
      ),
    );
  }
}

class _LateNotice extends StatelessWidget {
  const _LateNotice({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.chiliSoft,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.error_outline_rounded, color: AppColors.chili),
              const SizedBox(width: 12),
              Expanded(
                child: Text('$count cotisations sont en retard', style: AppType.sans(bold: true, color: AppColors.chili)),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.chili),
            ],
          ),
        ),
      ),
    );
  }
}

class _TreasurerSummary extends StatelessWidget {
  const _TreasurerSummary({required this.tontines});

  final List<Tontine> tontines;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final active = tontines.where((tontine) => tontine.isActive).toList();
    final drafts = tontines.where((tontine) => tontine.isDraft).length;
    if (active.isEmpty && drafts == 0) return const SizedBox.shrink();

    final due = active.fold<int>(0, (sum, tontine) => sum + (tontine.amountDueTotal ?? 0));
    final paid = active.fold<int>(0, (sum, tontine) => sum + (tontine.amountPaidTotal ?? 0));
    final percent = due == 0 ? 0 : (paid * 100 / due).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle('Suivi de la trésorerie'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (active.isNotEmpty) ...[
                  Text('Encaissé sur les tontines en cours', style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.muted)),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.end,
                    children: [
                      Money(paid, style: theme.textTheme.headlineSmall),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Text('sur ${fcfa(due)}', style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.muted)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  WovenBand(
                    segments: [for (final tontine in active) WeaveSegment(fill: tontine.paidRatio)],
                    semanticLabel: 'Encaissé : $percent %',
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Une case par tontine en cours',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
                if (drafts > 0) ...[
                  if (active.isNotEmpty) const SizedBox(height: 14),
                  Text(
                    drafts == 1 ? '1 tontine attend son démarrage.' : '$drafts tontines attendent leur démarrage.',
                    style: AppType.sans(bold: true, color: AppColors.goldText),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyTontines extends StatelessWidget {
  const _EmptyTontines({required this.canManage, required this.repository});

  final bool canManage;
  final TontineRepository repository;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Panel(
      radius: 20,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(canManage ? 'Créez votre première tontine' : 'Pas encore de tontine pour vous', style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            canManage
                ? 'Choisissez le type, le montant et la fréquence, puis invitez vos membres avec un code.'
                : 'Demandez un code d’invitation au responsable de votre groupe, puis touchez « Rejoindre avec un code » dans votre profil.',
            style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.muted),
          ),
          if (canManage) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => CreateTontineScreen(repository: repository)),
              ),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Nouvelle tontine'),
            ),
          ],
        ],
      ),
    );
  }
}

/// Une question de l'aide, différente chaque jour.
class _TipOfTheDay extends StatelessWidget {
  const _TipOfTheDay();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final questions = [for (final topic in helpTopics) ...topic.questions];
    final now = DateTime.now();
    final question = questions[now.difference(DateTime(now.year)).inDays % questions.length];

    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.lightbulb_outline_rounded, color: AppColors.goldText),
              const SizedBox(width: 12),
              Expanded(child: Text(question.question, style: theme.textTheme.titleMedium)),
            ],
          ),
          const SizedBox(height: 8),
          Text(question.answer, style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.muted)),
          TextButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const HelpScreen())),
            style: TextButton.styleFrom(padding: EdgeInsets.zero),
            child: const Text('Toutes les questions'),
          ),
        ],
      ),
    );
  }
}
