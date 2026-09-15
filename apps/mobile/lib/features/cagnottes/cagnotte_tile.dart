import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/format.dart';
import '../../core/widgets/ui.dart';
import '../../core/widgets/woven_band.dart';
import 'cagnotte.dart';
import 'cagnotte_detail_screen.dart';
import 'cagnotte_repository.dart';
import 'countdown.dart';

Tone cagnotteStatusTone(CagnotteStatus status) => switch (status) {
      CagnotteStatus.open => Tone.positive,
      CagnotteStatus.closed => Tone.gold,
      CagnotteStatus.drawn => Tone.indigo,
      CagnotteStatus.handedOver => Tone.neutral,
      CagnotteStatus.cancelled => Tone.danger,
    };

class CagnotteTile extends StatelessWidget {
  const CagnotteTile({super.key, required this.cagnotte, required this.repository});

  final Cagnotte cagnotte;
  final CagnotteRepository repository;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ratio = cagnotte.targetRatio;
    final details = cagnotte.isPrize
        ? 'Ticket à ${fcfa(cagnotte.ticketPrice ?? 0)}, ${countLabel(cagnotte.winnersCount ?? 0, 'gagnant', 'gagnants')}'
            '${cagnotte.ticketsCount > 0 ? ', ${countLabel(cagnotte.ticketsCount, 'ticket vendu', 'tickets vendus')}' : ''}'
        : 'Au profit de ${cagnotte.beneficiary?.name ?? 'un bénéficiaire'}';

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => CagnotteDetailScreen(repository: repository, cagnotteId: cagnotte.id)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: cagnotte.isPrize ? AppColors.goldSoft : AppColors.leafSoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(cagnotte.mode.icon, color: cagnotte.isPrize ? AppColors.goldText : AppColors.leafDeep),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(cagnotte.title, style: theme.textTheme.titleMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
                        Text(cagnotte.mode.label, style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.muted)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  StatusPill(label: cagnotte.status.label, tone: cagnotteStatusTone(cagnotte.status)),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 6,
                crossAxisAlignment: WrapCrossAlignment.end,
                children: [
                  Money(cagnotte.collectedAmount, style: theme.textTheme.titleLarge),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Text(
                      cagnotte.targetAmount == null ? 'réunis' : 'sur ${fcfa(cagnotte.targetAmount!)}',
                      style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.muted),
                    ),
                  ),
                ],
              ),
              Text(details, style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.muted)),
              if (ratio != null) ...[
                const SizedBox(height: 12),
                WovenBand(segments: progressSegments(ratio, 10), semanticLabel: 'Objectif atteint à ${(ratio * 100).round()} %'),
              ],
              if (cagnotte.isOpen) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.timer_outlined, size: 18, color: AppColors.goldText),
                    const SizedBox(width: 6),
                    Text('Clôture dans ', style: AppType.sans(size: 15, color: AppColors.goldText)),
                    Countdown(deadline: cagnotte.deadline, style: AppType.sans(size: 15, bold: true, color: AppColors.goldText)),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
