import '../../core/widgets/ui.dart';
import 'models.dart';

Tone tontineStatusTone(TontineStatus status) => switch (status) {
      TontineStatus.draft => Tone.gold,
      TontineStatus.active => Tone.positive,
      TontineStatus.completed => Tone.neutral,
      TontineStatus.cancelled => Tone.danger,
    };

bool isOverdue(DateTime dueOn) {
  final now = DateTime.now();
  return dueOn.isBefore(DateTime(now.year, now.month, now.day));
}

({String label, Tone tone}) cycleBadge(Cycle cycle) {
  if (cycle.status == CycleStatus.settled) return (label: 'Réglé', tone: Tone.positive);
  if (isOverdue(cycle.dueOn)) return (label: 'En retard', tone: Tone.danger);
  if (cycle.status == CycleStatus.open) return (label: 'À encaisser', tone: Tone.gold);
  return (label: 'À venir', tone: Tone.neutral);
}

({String label, Tone tone}) contributionBadge(Contribution contribution, {required bool late}) =>
    switch (contribution.status) {
      ContributionStatus.confirmed => (label: 'Confirmée', tone: Tone.positive),
      ContributionStatus.recorded => (label: 'À confirmer', tone: Tone.gold),
      ContributionStatus.pending when late => (label: 'En retard', tone: Tone.danger),
      ContributionStatus.pending => (label: 'À payer', tone: Tone.neutral),
    };
