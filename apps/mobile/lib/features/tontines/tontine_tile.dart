import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/format.dart';
import '../../core/widgets/ui.dart';
import '../../core/widgets/woven_band.dart';
import 'models.dart';
import 'status_style.dart';
import 'tontine_detail_screen.dart';
import 'tontine_repository.dart';

class TontineTile extends StatelessWidget {
  const TontineTile({super.key, required this.tontine, required this.repository});

  final Tontine tontine;
  final TontineRepository repository;

  String get _membersLine => tontine.maxMembers != null && tontine.type != TontineType.personalSavings
      ? '${tontine.memberCount} membres sur ${tontine.maxMembers}'
      : countLabel(tontine.memberCount, 'membre', 'membres');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cycles = tontine.cyclesCount ?? 0;
    final percent = (tontine.paidRatio * 100).round();

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => TontineDetailScreen(repository: repository, tontineId: tontine.id)),
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
                    decoration: BoxDecoration(color: AppColors.leafSoft, borderRadius: BorderRadius.circular(12)),
                    child: Icon(tontine.type.icon, color: AppColors.leafDeep),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(tontine.name, style: theme.textTheme.titleMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
                        Text(tontine.type.label, style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.muted)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  StatusPill(label: tontine.status.label, tone: tontineStatusTone(tontine.status)),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 6,
                crossAxisAlignment: WrapCrossAlignment.end,
                children: [
                  Money(tontine.amount, style: theme.textTheme.titleLarge),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Text(tontine.frequency.perPeriod, style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.muted)),
                  ),
                ],
              ),
              Text(_membersLine, style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.muted)),
              if (tontine.isActive && cycles > 0) ...[
                const SizedBox(height: 14),
                WovenBand(
                  segments: progressSegments(tontine.paidRatio, cycles),
                  semanticLabel: 'Cotisations encaissées : $percent %',
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text('$percent % encaissé', style: theme.textTheme.bodySmall?.copyWith(color: AppColors.muted)),
                    const SizedBox(width: 12),
                    if (tontine.nextDueOn != null)
                      Expanded(
                        child: Text(
                          'Prochaine échéance le ${shortDate(tontine.nextDueOn!)}',
                          textAlign: TextAlign.end,
                          style: theme.textTheme.bodySmall?.copyWith(color: AppColors.muted),
                        ),
                      ),
                  ],
                ),
              ],
              if (tontine.isDraft) ...[
                const SizedBox(height: 10),
                Text(
                  'Premier tour prévu le ${shortDate(tontine.startsOn)}',
                  style: AppType.sans(size: 15, bold: true, color: AppColors.goldText),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
