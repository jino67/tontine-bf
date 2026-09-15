import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../format.dart';
import 'ui.dart';

/// Éléments communs aux tirages vérifiables (ordre de passage et gagnants des cagnottes).
const monoStyle = TextStyle(fontFamily: 'monospace', fontSize: 13, height: 1.5, color: AppColors.ink);

class Fingerprint extends StatelessWidget {
  const Fingerprint({super.key, required this.hash});

  final String hash;

  @override
  Widget build(BuildContext context) {
    final groups = [for (var i = 0; i < hash.length; i += 8) hash.substring(i, (i + 8).clamp(0, hash.length))];
    return Panel(
      color: AppColors.indigoSoft,
      borderColor: AppColors.indigoSoft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Empreinte publiée', style: AppType.sans(bold: true, color: AppColors.indigo)),
          const SizedBox(height: 8),
          SelectableText(groups.join(' '), style: monoStyle.copyWith(fontSize: 15, color: AppColors.indigo)),
        ],
      ),
    );
  }
}

class VerificationBanner extends StatelessWidget {
  const VerificationBanner({super.key, required this.verified, required this.successMessage});

  final bool verified;
  final String successMessage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Panel(
      color: verified ? AppColors.leafSoft : AppColors.chiliSoft,
      borderColor: verified ? AppColors.leafSoft : AppColors.chiliSoft,
      radius: 20,
      padding: const EdgeInsets.all(18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(verified ? Icons.verified_rounded : Icons.gpp_bad_rounded, color: verified ? AppColors.leafDeep : AppColors.chili, size: 30),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(verified ? 'Tirage vérifié sur ce téléphone' : 'Vérification échouée', style: theme.textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(
                  verified
                      ? successMessage
                      : 'Le résultat ne correspond pas à l’empreinte publiée. Signalez-le à votre organisation.',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Les trois étapes d'un tirage, dans l'ordre où elles se déroulent.
class DrawSteps extends StatelessWidget {
  const DrawSteps({super.key, required this.current});

  final int current;

  static const _labels = ['Empreinte publiée', 'Révélation après la date annoncée', 'Vérification sur chaque téléphone'];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < _labels.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: i <= current ? AppColors.indigo : AppColors.indigoSoft,
                    shape: BoxShape.circle,
                  ),
                  child: i < current || i == 0
                      ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
                      : Text('${i + 1}', style: AppType.sans(size: 13, bold: true, color: i <= current ? Colors.white : AppColors.indigo)),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(_labels[i], style: AppType.sans(bold: i <= current))),
              ],
            ),
          ),
      ],
    );
  }
}

/// Champ de date et heure de révélation. Une date passée est ramenée à dans cinq minutes.
class RevealDateField extends StatelessWidget {
  const RevealDateField({super.key, required this.value, required this.onChanged});

  final DateTime value;
  final ValueChanged<DateTime> onChanged;

  Future<void> _pick(BuildContext context) async {
    final today = DateUtils.dateOnly(DateTime.now());
    final date = await showDatePicker(
      context: context,
      initialDate: value.isBefore(today) ? today : value,
      firstDate: today,
      lastDate: today.add(const Duration(days: 60)),
      helpText: 'Date de révélation',
    );
    if (date == null || !context.mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(value),
      helpText: 'Heure de révélation',
    );
    if (time == null) return;

    final chosen = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    onChanged(chosen.isBefore(DateTime.now()) ? DateTime.now().add(const Duration(minutes: 5)) : chosen);
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _pick(context),
      child: InputDecorator(
        decoration: const InputDecoration(labelText: 'Révélation possible à partir du', suffixIcon: Icon(Icons.schedule_rounded)),
        child: Text(dateAndTime(value), style: Theme.of(context).textTheme.bodyLarge),
      ),
    );
  }
}

/// Message sous le bouton de révélation tant que la date n'est pas passée.
String revealHint(BuildContext context, DateTime revealAfter) {
  final local = revealAfter.toLocal();
  return 'Le bouton s’activera ${relativeDay(local)} à ${TimeOfDay.fromDateTime(local).format(context)}.';
}
