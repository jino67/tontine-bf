import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/format.dart';
import '../../core/session/session_scope.dart';
import '../../core/widgets/brand.dart';
import '../../core/widgets/ui.dart';
import '../../core/widgets/verification.dart';
import '../organizations/organization.dart';
import '../payments/pay_online.dart';
import '../sharing/share_actions.dart';
import '../tontines/models.dart' show ContributionStatus, PaymentMethod;
import 'cagnotte.dart';
import 'cagnotte_repository.dart';
import 'cagnotte_sheets.dart';
import 'cagnotte_tile.dart';
import 'countdown.dart';
import 'prize_draw.dart';

String _how(PaymentMethod? method) => switch (method) {
      null => '',
      PaymentMethod.cash => ' en espèces',
      _ => ' par ${method.label}',
    };

class CagnotteDetailScreen extends StatefulWidget {
  const CagnotteDetailScreen({super.key, required this.repository, required this.cagnotteId});

  final CagnotteRepository repository;
  final int cagnotteId;

  @override
  State<CagnotteDetailScreen> createState() => _CagnotteDetailScreenState();
}

class _CagnotteDetailScreenState extends State<CagnotteDetailScreen> {
  late Future<Cagnotte> _future;
  bool _busy = false;
  late DateTime _revealAfter;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _revealAfter = DateTime(now.year, now.month, now.day, now.hour).add(const Duration(hours: 2));
    _future = widget.repository.get(widget.cagnotteId);
    widget.repository.revision.addListener(_refresh);
    // Réactive le bouton de révélation dès que la date est passée.
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    widget.repository.revision.removeListener(_refresh);
    super.dispose();
  }

  Future<void> _refresh() async {
    final future = widget.repository.get(widget.cagnotteId);
    setState(() => _future = future);
    try {
      await future;
    } catch (_) {
      // L'erreur est affichée à l'écran.
    }
  }

  Future<void> _run(Future<void> Function() action, String done) async {
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) showDone(context, done);
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _close(Cagnotte cagnotte) async {
    final confirmed = await confirmAction(
      context,
      title: 'Clôturer maintenant ?',
      message: 'La cagnotte n’acceptera plus de participation, même si le compte à rebours n’est pas terminé.',
      confirmLabel: 'Clôturer',
    );
    if (confirmed && mounted) await _run(() => widget.repository.close(cagnotte.id), 'Cagnotte clôturée');
  }

  Future<void> _recordContribution(Cagnotte cagnotte, [CagnotteContribution? contribution]) async {
    final saved = await showCagnotteContributionSheet(
      context,
      repository: widget.repository,
      cagnotte: cagnotte,
      contribution: contribution,
    );
    if (saved == true && mounted) showDone(context, 'Participation enregistrée');
  }

  Future<void> _handover(Cagnotte cagnotte) async {
    final saved = await showTransferSheet(
      context,
      title: 'Remise des fonds',
      message: 'Somme réunie : ${fcfa(cagnotte.collectedAmount)}. Indiquez ce qui a été remis à ${cagnotte.beneficiary?.name ?? 'la personne'}.',
      submitLabel: 'Enregistrer la remise',
      initialAmount: cagnotte.collectedAmount,
      allowPayDunya: true,
      onSubmit: (input) => widget.repository.recordHandover(
        cagnotte.id,
        amount: input.amount!,
        method: input.method,
        reference: input.reference,
        withdrawMode: input.withdrawMode,
        phone: input.phone,
      ),
    );
    if (saved == true && mounted) showDone(context, 'Remise des fonds enregistrée');
  }

  Future<void> _payout(Cagnotte cagnotte, CagnotteWinner winner) async {
    final saved = await showTransferSheet(
      context,
      title: 'Remise du gain',
      message: '${capitalize(ordinal(winner.rank))} gain : ${fcfa(winner.prizeAmount)} pour ${winner.user?.displayName ?? 'le gagnant'}.',
      submitLabel: 'Enregistrer la remise',
      allowPayDunya: true,
      initialPhone: winner.user?.phone,
      onSubmit: (input) => widget.repository.recordPayout(
        cagnotte.id,
        winner.id,
        method: input.method,
        reference: input.reference,
        withdrawMode: input.withdrawMode,
        phone: input.phone,
      ),
    );
    if (saved == true && mounted) showDone(context, 'Remise du gain enregistrée');
  }

  Future<void> _participateOnline(Cagnotte cagnotte) async {
    final amount = await pickParticipationAmount(context, cagnotte);
    if (amount == null || !mounted) return;
    final paid = await payOnline(context, start: (payments) => payments.payCagnotte(cagnotte.id, amount));
    if (paid) widget.repository.revision.value++;
  }

  Future<void> _commitDraw(Cagnotte cagnotte) async {
    final confirmed = await confirmAction(
      context,
      title: 'Lancer le tirage ?',
      message: 'La liste des ${countLabel(cagnotte.ticketsCount, 'ticket', 'tickets')} et l’empreinte seront publiées tout de suite. '
          'Le tirage pourra être révélé à partir du ${dateAndTime(_revealAfter)}. Cette date ne pourra plus être changée.',
      confirmLabel: 'Lancer',
    );
    if (confirmed && mounted) {
      await _run(() => widget.repository.commitDraw(cagnotte.id, _revealAfter), 'Tirage lancé, empreinte publiée');
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    final role = session.currentOrganization!.role;
    final me = session.user?.id;

    return Scaffold(
      appBar: AppBar(),
      body: FutureBuilder<Cagnotte>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.hasError && !snapshot.hasData) return ErrorView(error: snapshot.error!, onRetry: _refresh);
          if (!snapshot.hasData) return const LoadingView();

          final cagnotte = snapshot.requireData;

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 40),
              children: [
                _Header(cagnotte: cagnotte),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _Hero(cagnotte: cagnotte, onFinished: _refresh),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 4, 20, 0),
                    child: TextButton.icon(
                      onPressed: () => shareCagnotte(context, cagnotte, organizationId: session.currentOrganization!.id, canManage: role.canManage, onChanged: _refresh),
                      icon: const Icon(Icons.ios_share_rounded, size: 20),
                      label: const Text('Partager'),
                    ),
                  ),
                ),
                if (cagnotte.acceptsContributions)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    child: FilledButton.icon(
                      onPressed: () => _participateOnline(cagnotte),
                      icon: const Icon(Icons.phone_iphone_rounded),
                      label: Text(cagnotte.isPrize ? 'Acheter des tickets en ligne' : 'Participer en ligne'),
                    ),
                  ),
                if (cagnotte.isPrize) ..._prizeSections(cagnotte, role, me) else ..._solidaritySections(cagnotte, role, me),
                ..._contributionSections(cagnotte, role, me),
                if (role.canManage && cagnotte.isOpen)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                    child: OutlinedButton.icon(
                      onPressed: _busy ? null : () => _close(cagnotte),
                      icon: const Icon(Icons.lock_clock_outlined),
                      label: const Text('Clôturer maintenant'),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  List<Widget> _solidaritySections(Cagnotte cagnotte, Role role, int? me) {
    final theme = Theme.of(context);
    final beneficiary = cagnotte.beneficiary;
    final handover = cagnotte.handover;
    final isBeneficiary = beneficiary?.userId != null && beneficiary!.userId == me;

    final Widget handoverBody;
    if (handover != null) {
      final confirmed = handover.confirmedAt != null;
      handoverBody = Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Money(handover.amount, style: theme.textTheme.headlineSmall)),
                StatusPill(
                  label: confirmed ? 'Réception confirmée' : (beneficiary?.isMember ?? false) ? 'À confirmer' : 'Remis',
                  tone: confirmed || !(beneficiary?.isMember ?? false) ? Tone.positive : Tone.gold,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Remis le ${dateAndTime(handover.handedOverAt)}${_how(handover.method)}',
              style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.muted),
            ),
            if (handover.reference != null) Text('Référence ${handover.reference}', style: theme.textTheme.bodySmall),
            if (isBeneficiary && !confirmed) ...[
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _busy ? null : () => _run(() => widget.repository.confirmHandover(cagnotte.id), 'Réception confirmée'),
                child: const Text('Confirmer la réception'),
              ),
            ],
          ],
        ),
      );
    } else if (cagnotte.handoverPayout?.isProcessing ?? false) {
      handoverBody = Panel(
        color: AppColors.indigoSoft,
        borderColor: AppColors.indigoSoft,
        child: Text(
          'Envoi par PayDunya en cours : ${fcfa(cagnotte.handoverPayout!.amount)} vers le compte mobile money indiqué. '
          'La remise sera enregistrée dès que PayDunya confirme.',
          style: theme.textTheme.bodyLarge,
        ),
      );
    } else if (cagnotte.isOpen) {
      handoverBody = Panel(
        child: Text('Les fonds seront remis à la clôture de la cagnotte.', style: theme.textTheme.bodyLarge?.copyWith(color: AppColors.muted)),
      );
    } else if (role.canManage) {
      handoverBody = Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'La collecte est terminée. Envoyez les fonds par PayDunya, ou remettez-les puis enregistrez la remise.',
              style: theme.textTheme.bodyLarge,
            ),
            if (cagnotte.handoverPayout?.isFailed ?? false) ...[
              const SizedBox(height: 8),
              Text(
                'Le dernier envoi PayDunya a échoué${cagnotte.handoverPayout!.failureReason == null ? '.' : ' : ${cagnotte.handoverPayout!.failureReason}'}',
                style: AppType.sans(size: 14, color: AppColors.chili),
              ),
            ],
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _busy ? null : () => _handover(cagnotte),
              icon: const Icon(Icons.handshake_outlined),
              label: const Text('Enregistrer la remise des fonds'),
            ),
          ],
        ),
      );
    } else {
      handoverBody = Panel(
        child: Text(
          'Le responsable va remettre les fonds au bénéficiaire et enregistrer la remise ici.',
          style: theme.textTheme.bodyLarge?.copyWith(color: AppColors.muted),
        ),
      );
    }

    return [
      const SectionTitle('Bénéficiaire'),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Panel(
          color: AppColors.goldSoft,
          borderColor: AppColors.goldSoft,
          radius: 20,
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              MemberAvatar(name: beneficiary?.name, size: 52, tone: Tone.positive),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isBeneficiary ? 'Cette cagnotte est pour vous' : 'Au profit de',
                      style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.goldText),
                    ),
                    Text(beneficiary?.name ?? 'Bénéficiaire', style: theme.textTheme.titleLarge),
                    Text(
                      (beneficiary?.isMember ?? false) ? 'Membre de l’organisation' : 'Personne extérieure à l’organisation',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      const SectionTitle('Remise des fonds'),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: handoverBody),
    ];
  }

  List<Widget> _prizeSections(Cagnotte cagnotte, Role role, int? me) {
    final theme = Theme.of(context);
    final notes = [
      if (cagnotte.isOpen) 'Montants calculés sur la somme réunie à ce jour.',
      if (cagnotte.feePercent > 0) 'Commission de l’organisation : ${cagnotte.feePercent} %, retenue avant le partage.',
    ];

    return [
      const SectionTitle('Gains'),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var i = 0; i < cagnotte.prizes.length; i++) ...[
                if (i > 0) const Divider(indent: 64),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                  leading: RankBadge(rank: cagnotte.prizes[i].rank),
                  title: Text('${capitalize(ordinal(cagnotte.prizes[i].rank))} gain'),
                  subtitle: Text('${percentLabel(cagnotte.prizes[i].percent)} de la somme à partager'),
                  trailing: Money(cagnotte.prizes[i].amount, style: AppType.sans(size: 17, bold: true)),
                ),
              ],
            ],
          ),
        ),
      ),
      if (notes.isNotEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
          child: Text(notes.join(' '), style: theme.textTheme.bodySmall),
        ),
      const SectionTitle('Tirage des gagnants'),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: _drawBody(cagnotte, role, me)),
    ];
  }

  Widget _drawBody(Cagnotte cagnotte, Role role, int? me) {
    final theme = Theme.of(context);
    final draw = cagnotte.draw;

    if (draw == null) {
      if (cagnotte.isOpen || !role.canManage) {
        return Panel(
          child: Text(
            cagnotte.isOpen
                ? 'Le tirage aura lieu après la clôture. La liste des tickets et l’empreinte du tirage seront publiées avant la révélation.'
                : 'Le responsable va lancer le tirage. Vous pourrez le révéler et le vérifier ici dès la date annoncée.',
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
            RevealDateField(value: _revealAfter, onChanged: (value) => setState(() => _revealAfter = value)),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _busy ? null : () => _commitDraw(cagnotte),
                style: FilledButton.styleFrom(backgroundColor: AppColors.indigo),
                child: _busy
                    ? const ButtonSpinner()
                    : Text('Lancer le tirage (${countLabel(cagnotte.ticketsCount, 'ticket', 'tickets')})'),
              ),
            ),
          ],
        ),
      );
    }

    if (!draw.isRevealed) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DrawSteps(current: draw.canReveal ? 1 : 0),
          const SizedBox(height: 16),
          Fingerprint(hash: draw.seedHash),
          const SizedBox(height: 12),
          LabeledValue(label: 'Révélation possible', value: dateAndTime(draw.revealAfter), icon: Icons.schedule_rounded),
          LabeledValue(label: 'Tickets en jeu', value: '${draw.tickets.length}', icon: Icons.confirmation_number_outlined),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: draw.canReveal && !_busy ? () => _run(() => widget.repository.revealDraw(cagnotte.id), 'Tirage révélé') : null,
              style: FilledButton.styleFrom(backgroundColor: AppColors.indigo),
              child: _busy ? const ButtonSpinner() : const Text('Révéler le tirage'),
            ),
          ),
          if (!draw.canReveal) ...[
            const SizedBox(height: 8),
            Text(revealHint(context, draw.revealAfter), style: theme.textTheme.bodySmall),
          ],
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        VerificationBanner(
          verified: PrizeDraw.verify(cagnotte),
          successMessage: 'La graine correspond à l’empreinte publiée, et les gagnants ont été recalculés ici à partir de la liste des tickets.',
        ),
        const SizedBox(height: 16),
        if (cagnotte.winners.isEmpty)
          Panel(child: Text('Aucun gagnant : aucun ticket n’a été vendu.', style: theme.textTheme.bodyLarge))
        else
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (var i = 0; i < cagnotte.winners.length; i++) ...[
                  if (i > 0) const Divider(indent: 64),
                  _WinnerRow(
                    winner: cagnotte.winners[i],
                    isMe: cagnotte.winners[i].user?.id == me,
                    canManage: role.canManage,
                    busy: _busy,
                    onPayout: () => _payout(cagnotte, cagnotte.winners[i]),
                    onConfirm: () => _run(
                      () => widget.repository.confirmPayout(cagnotte.id, cagnotte.winners[i].id),
                      'Réception du gain confirmée',
                    ),
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
              Text('Tickets en jeu (${draw.tickets.length})', style: theme.textTheme.bodySmall),
              SelectableText(draw.tickets.join('  '), style: monoStyle),
              const SizedBox(height: 10),
              Text(
                'Contrôle : sha256(graine) doit donner l’empreinte. Les tickets sont triés par sha256(graine + "|" + ticket). '
                'Chaque membre gagne au plus une fois, dans l’ordre de son premier ticket. « u12#3 » est le 3e ticket du membre 12.',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _contributionSections(Cagnotte cagnotte, Role role, int? me) {
    final theme = Theme.of(context);
    final canAdd = role.canRecordPayments && cagnotte.acceptsContributions;
    final contributions = cagnotte.contributions;

    return [
      SectionTitle(
        'Participations (${contributions.length})',
        trailing: canAdd && contributions.isNotEmpty
            ? TextButton(onPressed: () => _recordContribution(cagnotte), child: const Text('Ajouter'))
            : null,
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: contributions.isEmpty
            ? Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cagnotte.acceptsContributions ? 'Aucune participation pour le moment.' : 'Aucune participation n’a été enregistrée.',
                      style: theme.textTheme.bodyLarge?.copyWith(color: AppColors.muted),
                    ),
                    if (canAdd) ...[
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: () => _recordContribution(cagnotte),
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Enregistrer une participation'),
                      ),
                    ],
                  ],
                ),
              )
            : Card(
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    for (var i = 0; i < contributions.length; i++) ...[
                      if (i > 0) const Divider(indent: 64),
                      _ContributionRow(
                        contribution: contributions[i],
                        showTickets: cagnotte.isPrize,
                        isMine: contributions[i].user?.id == me,
                        canEdit: role.canRecordPayments &&
                            contributions[i].status != ContributionStatus.confirmed &&
                            !cagnotte.isLocked,
                        busy: _busy,
                        onEdit: () => _recordContribution(cagnotte, contributions[i]),
                        onConfirm: () => _run(
                          () => widget.repository.confirmContribution(cagnotte.id, contributions[i].id),
                          'Participation confirmée',
                        ),
                      ),
                    ],
                  ],
                ),
              ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
        child: Text(
          'Le trésorier enregistre chaque participation reçue, puis la personne concernée la confirme. '
          'Une participation confirmée est verrouillée.',
          style: theme.textTheme.bodySmall,
        ),
      ),
    ];
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.cagnotte});

  final Cagnotte cagnotte;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StatusPill(label: cagnotte.status.label, tone: cagnotteStatusTone(cagnotte.status)),
              const SizedBox(width: 8),
              Flexible(child: Text(cagnotte.mode.label, style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.muted))),
            ],
          ),
          const SizedBox(height: 12),
          Text(cagnotte.title, style: theme.textTheme.headlineMedium),
          if (cagnotte.description != null) ...[
            const SizedBox(height: 6),
            Text(cagnotte.description!, style: theme.textTheme.bodyLarge?.copyWith(color: AppColors.muted)),
          ],
        ],
      ),
    );
  }
}

/// Bloc principal : compte à rebours, somme réunie et chiffres clés.
class _Hero extends StatelessWidget {
  const _Hero({required this.cagnotte, required this.onFinished});

  final Cagnotte cagnotte;
  final VoidCallback onFinished;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const soft = Color(0xC7FFFFFF);
    final ended = cagnotte.closedAt ?? cagnotte.endsAt;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: cagnotte.isPrize ? AppColors.indigo : AppColors.leafDeep,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (cagnotte.isOpen) ...[
            Text('Clôture dans', style: theme.textTheme.bodyMedium?.copyWith(color: soft)),
            const SizedBox(height: 2),
            Countdown(
              deadline: cagnotte.deadline,
              onFinished: onFinished,
              style: AppType.sans(size: 36, bold: true, color: Colors.white, height: 1.1),
            ),
            const SizedBox(height: 4),
            Text('Fin prévue le ${dateAndTime(cagnotte.endsAt)}', style: theme.textTheme.bodySmall?.copyWith(color: soft)),
          ] else
            Text('Collecte terminée le ${dateAndTime(ended)}', style: AppType.sans(size: 17, bold: true, color: Colors.white)),
          const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider(color: Color(0x33FFFFFF))),
          Text('Somme réunie', style: theme.textTheme.bodyMedium?.copyWith(color: soft)),
          Money(cagnotte.collectedAmount, style: theme.textTheme.displaySmall?.copyWith(color: Colors.white)),
          if (cagnotte.targetAmount != null)
            Text(
              'Objectif : ${fcfa(cagnotte.targetAmount!)}, atteint à ${((cagnotte.targetRatio ?? 0) * 100).round()} %',
              style: theme.textTheme.bodyMedium?.copyWith(color: soft),
            ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 22,
            runSpacing: 10,
            children: [
              _HeroFact(label: 'Participations', value: '${cagnotte.participationsCount}'),
              if (cagnotte.isPrize) ...[
                _HeroFact(label: 'Ticket', value: fcfa(cagnotte.ticketPrice ?? 0)),
                _HeroFact(label: 'Tickets vendus', value: '${cagnotte.ticketsCount}'),
                if (cagnotte.myTickets != null) _HeroFact(label: 'Mes tickets', value: '${cagnotte.myTickets}'),
              ] else
                _HeroFact(label: 'Minimum', value: fcfa(cagnotte.minAmount)),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroFact extends StatelessWidget {
  const _HeroFact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppType.sans(size: 13, color: const Color(0xC7FFFFFF))),
        Text(value, style: AppType.sans(size: 17, bold: true, color: Colors.white, tabular: true)),
      ],
    );
  }
}

class _WinnerRow extends StatelessWidget {
  const _WinnerRow({
    required this.winner,
    required this.isMe,
    required this.canManage,
    required this.busy,
    required this.onPayout,
    required this.onConfirm,
  });

  final CagnotteWinner winner;
  final bool isMe;
  final bool canManage;
  final bool busy;
  final VoidCallback onPayout;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = winner.user?.displayName ?? 'Membre';
    final sending = winner.payout?.isProcessing ?? false;
    final badge = winner.paidAt == null
        ? (sending ? (label: 'Envoi en cours', tone: Tone.indigo) : (label: 'À remettre', tone: Tone.gold))
        : winner.confirmedAt == null
            ? (label: 'À confirmer', tone: Tone.gold)
            : (label: 'Reçu', tone: Tone.positive);
    final showPayout = canManage && winner.paidAt == null && !sending;
    final showConfirm = isMe && winner.paidAt != null && winner.confirmedAt == null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RankBadge(rank: winner.rank),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(isMe ? '$name (vous)' : name, style: theme.textTheme.titleSmall),
                    Money(winner.prizeAmount, style: AppType.sans(size: 17, bold: true, color: AppColors.goldText)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              StatusPill(label: badge.label, tone: badge.tone),
            ],
          ),
          if (winner.paidAt != null)
            Padding(
              padding: const EdgeInsets.only(left: 48, top: 6),
              child: Text(
                'Remis le ${dateAndTime(winner.paidAt!)}${_how(winner.paidMethod)}'
                '${winner.paidReference == null ? '' : ', référence ${winner.paidReference}'}',
                style: theme.textTheme.bodySmall,
              ),
            ),
          if (winner.paidAt == null && (winner.payout?.isFailed ?? false))
            Padding(
              padding: const EdgeInsets.only(left: 48, top: 6),
              child: Text(
                'Le dernier envoi PayDunya a échoué${winner.payout!.failureReason == null ? '.' : ' : ${winner.payout!.failureReason}'}',
                style: AppType.sans(size: 14, color: AppColors.chili),
              ),
            ),
          if (showPayout || showConfirm)
            Padding(
              padding: const EdgeInsets.only(left: 48, top: 10),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (showPayout)
                    OutlinedButton(onPressed: busy ? null : onPayout, style: CompactButtons.outlined, child: const Text('Enregistrer la remise')),
                  if (showConfirm)
                    FilledButton(onPressed: busy ? null : onConfirm, style: CompactButtons.filled, child: const Text('Confirmer la réception')),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ContributionRow extends StatelessWidget {
  const _ContributionRow({
    required this.contribution,
    required this.showTickets,
    required this.isMine,
    required this.canEdit,
    required this.busy,
    required this.onEdit,
    required this.onConfirm,
  });

  final CagnotteContribution contribution;
  final bool showTickets;
  final bool isMine;
  final bool canEdit;
  final bool busy;
  final VoidCallback onEdit;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = contribution.user?.displayName ?? 'Membre';
    final confirmed = contribution.status == ContributionStatus.confirmed;
    final showConfirm = isMine && contribution.status == ContributionStatus.recorded;
    final details = '${fcfa(contribution.amount)}${_how(contribution.method)}'
        '${showTickets ? ', ${countLabel(contribution.tickets, 'ticket', 'tickets')}' : ''}'
        '${contribution.reference == null ? '' : '\nRéférence ${contribution.reference}'}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MemberAvatar(name: contribution.user?.name),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(isMine ? '$name (vous)' : name, style: theme.textTheme.titleSmall),
                    const SizedBox(height: 2),
                    Text(details, style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.muted)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              StatusPill(label: confirmed ? 'Confirmée' : 'À confirmer', tone: confirmed ? Tone.positive : Tone.gold),
            ],
          ),
          if (canEdit || showConfirm)
            Padding(
              padding: const EdgeInsets.only(left: 52, top: 10),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (canEdit) OutlinedButton(onPressed: busy ? null : onEdit, style: CompactButtons.outlined, child: const Text('Modifier')),
                  if (showConfirm)
                    FilledButton(onPressed: busy ? null : onConfirm, style: CompactButtons.filled, child: const Text('Confirmer ma participation')),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
