import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/format.dart';
import '../../core/widgets/ui.dart';
import '../fees/fees_screen.dart';
import 'wallet.dart';
import 'wallet_repository.dart';
import 'wallet_sheets.dart';

/// Solde du membre, ce qu'il peut en faire, et l'historique de ses mouvements.
class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key, required this.repository});

  final WalletRepository repository;

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletData {
  const _WalletData(this.summary, this.movements);

  final WalletSummary summary;
  final List<WalletMovement> movements;
}

class _WalletScreenState extends State<WalletScreen> {
  late Future<_WalletData> _future;

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

  Future<_WalletData> _load() async {
    final summary = await widget.repository.summary();
    final movements = await widget.repository.movements();

    return _WalletData(summary, movements);
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mon portefeuille'),
        actions: [
          IconButton(
            tooltip: 'Frais de service',
            icon: const Icon(Icons.receipt_long_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const FeesScreen()),
            ),
          ),
        ],
      ),
      body: FutureBuilder<_WalletData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.hasError && !snapshot.hasData) return ErrorView(error: snapshot.error!, onRetry: _refresh);
          if (!snapshot.hasData) return const LoadingView();

          final data = snapshot.requireData;

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 32),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: _BalanceCard(summary: data.summary),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: _Actions(repository: widget.repository, summary: data.summary),
                ),
                const SectionTitle('Mouvements'),
                if (data.movements.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Panel(
                      child: Text(
                        'Aucun mouvement pour l’instant. Votre solde se garnit avec vos gains, '
                        'les tours que vous recevez et les remboursements.',
                      ),
                    ),
                  )
                else
                  for (final movement in data.movements)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                      child: _MovementTile(movement: movement),
                    ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.summary});

  final WalletSummary summary;

  String get _levelText => switch (summary.level) {
        0 => 'Compte nouveau',
        1 => 'Compte confirmé',
        _ => 'Identité vérifiée',
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Panel(
      radius: 24,
      padding: const EdgeInsets.all(20),
      color: AppColors.leafSoft,
      borderColor: AppColors.leafSoft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Solde disponible', style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.leafDeep)),
          const SizedBox(height: 4),
          Text(
            fcfa(summary.balance),
            style: AppType.sans(size: 32, bold: true, color: AppColors.leafDeep, height: 1.1),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              StatusPill(label: _levelText, tone: Tone.positive, icon: Icons.verified_user_outlined),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Plafond ${fcfa(summary.maxBalance)}',
                  style: theme.textTheme.bodySmall?.copyWith(color: AppColors.leafDeep),
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({required this.repository, required this.summary});

  final WalletRepository repository;
  final WalletSummary summary;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: () => showTransferSheet(context, repository: repository, summary: summary),
                icon: const Icon(Icons.send_rounded),
                label: const Text('Envoyer'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => showWithdrawSheet(context, repository: repository, summary: summary),
                icon: const Icon(Icons.call_made_rounded),
                label: const Text('Retirer'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (summary.depositsEnabled)
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => showDepositSheet(context, repository: repository, summary: summary),
              icon: const Icon(Icons.call_received_rounded),
              label: const Text('Déposer de l’argent'),
            ),
          )
        else
          const Panel(
            child: Text(
              'Le dépôt libre n’est pas encore ouvert : garder l’argent du public est une activité '
              'encadrée par la BCEAO. Votre solde se garnit avec vos gains, les tours que vous '
              'recevez et les remboursements.',
            ),
          ),
        const SizedBox(height: 10),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.smartphone_rounded, color: AppColors.muted),
          title: const Text('Numéro qui reçoit les retraits'),
          subtitle: Text(
            summary.payoutPhone == null
                ? 'Aucun numéro enregistré'
                : '${phoneDisplay(summary.payoutPhone!)} · ${withdrawModes[summary.payoutMode] ?? summary.payoutMode}',
          ),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => showPayoutPhoneSheet(context, repository: repository, summary: summary),
        ),
      ],
    );
  }
}

class _MovementTile extends StatelessWidget {
  const _MovementTile({required this.movement});

  final WalletMovement movement;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tone = movement.hasFailed
        ? Tone.danger
        : movement.isPending
            ? Tone.gold
            : (movement.isCredit ? Tone.positive : Tone.neutral);
    final colors = toneColors(tone);

    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: colors.background, shape: BoxShape.circle),
                child: Icon(
                  movement.isCredit ? Icons.south_west_rounded : Icons.north_east_rounded,
                  size: 20,
                  color: colors.foreground,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(movement.label, style: AppType.sans(bold: true)),
                    if (movement.createdAt != null)
                      Text(
                        dateAndTime(movement.createdAt!),
                        style: theme.textTheme.bodySmall?.copyWith(color: AppColors.muted),
                      ),
                  ],
                ),
              ),
              Text(
                '${movement.isCredit ? '+' : '−'}${fcfa(movement.amount)}',
                style: AppType.sans(bold: true, color: colors.foreground),
              ),
            ],
          ),
          if (movement.description != null) ...[
            const SizedBox(height: 8),
            Text(movement.description!, style: theme.textTheme.bodySmall?.copyWith(color: AppColors.muted)),
          ],
          if (movement.feeAmount > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Dont ${fcfa(movement.feeAmount)} de frais de service',
                style: theme.textTheme.bodySmall?.copyWith(color: AppColors.muted),
              ),
            ),
          if (movement.isPending)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: StatusPill(label: 'En attente de l’opérateur', tone: Tone.gold, icon: Icons.schedule_rounded),
            ),
          if (movement.failureReason != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Refusé : ${movement.failureReason}. La somme est revenue sur votre solde.',
                style: theme.textTheme.bodySmall?.copyWith(color: AppColors.chili),
              ),
            ),
        ],
      ),
    );
  }
}
