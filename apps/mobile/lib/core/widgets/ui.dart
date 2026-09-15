import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../api/api_exception.dart';
import '../format.dart';

enum Tone { neutral, positive, gold, indigo, danger }

({Color background, Color foreground}) toneColors(Tone tone) => switch (tone) {
      Tone.neutral => (background: AppColors.cotton, foreground: AppColors.muted),
      Tone.positive => (background: AppColors.leafSoft, foreground: AppColors.leafDeep),
      Tone.gold => (background: AppColors.goldSoft, foreground: AppColors.goldText),
      Tone.indigo => (background: AppColors.indigoSoft, foreground: AppColors.indigo),
      Tone.danger => (background: AppColors.chiliSoft, foreground: AppColors.chili),
    };

class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.label, this.tone = Tone.neutral, this.icon});

  final String label;
  final Tone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colors = toneColors(tone);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: colors.background, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 14, color: colors.foreground), const SizedBox(width: 4)],
          Text(label, style: AppType.sans(size: 13, bold: true, color: colors.foreground, height: 1.2)),
        ],
      ),
    );
  }
}

/// Montant en chiffres alignés, toujours suivi de « FCFA ».
class Money extends StatelessWidget {
  const Money(this.amount, {super.key, this.style});

  final int amount;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final base = style ?? Theme.of(context).textTheme.titleMedium;
    return Text(fcfa(amount), style: base?.copyWith(fontFeatures: AppTheme.tabularFigures));
  }
}

class MemberAvatar extends StatelessWidget {
  const MemberAvatar({super.key, required this.name, this.size = 40, this.tone});

  final String? name;
  final double size;
  final Tone? tone;

  @override
  Widget build(BuildContext context) {
    const palette = [Tone.positive, Tone.gold, Tone.indigo];
    final chosen = tone ?? palette[(name ?? '').codeUnits.fold<int>(0, (sum, unit) => sum + unit) % palette.length];
    final colors = toneColors(chosen);

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: colors.background, shape: BoxShape.circle),
      child: Text(
        initials(name),
        style: AppType.sans(size: size * 0.36, bold: true, color: colors.foreground, height: 1),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.trailing, this.padding = const EdgeInsets.fromLTRB(20, 28, 20, 10)});

  final String title;
  final Widget? trailing;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium)),
          ?trailing,
        ],
      ),
    );
  }
}

/// Bloc blanc bordé. Le rayon suit la hiérarchie : 24 pour un bloc principal, 16 pour une liste.
class Panel extends StatelessWidget {
  const Panel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 16,
    this.color = Colors.white,
    this.borderColor = AppColors.line,
  });

  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final Color color;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor),
      ),
      child: child,
    );
  }
}

class LabeledValue extends StatelessWidget {
  const LabeledValue({super.key, required this.label, required this.value, this.icon});

  final String label;
  final String value;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          if (icon != null) ...[Icon(icon, size: 20, color: AppColors.muted), const SizedBox(width: 12)],
          Expanded(child: Text(label, style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.muted))),
          const SizedBox(width: 12),
          Flexible(
            child: Text(value, textAlign: TextAlign.end, style: AppType.sans(bold: true)),
          ),
        ],
      ),
    );
  }
}

class LoadingView extends StatelessWidget {
  const LoadingView({super.key});

  @override
  Widget build(BuildContext context) => const Center(child: CircularProgressIndicator());
}

class MessageView extends StatelessWidget {
  const MessageView({super.key, required this.icon, required this.title, required this.message, this.action, this.tone = Tone.positive});

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;
  final Tone tone;

  @override
  Widget build(BuildContext context) {
    final colors = toneColors(tone);
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(color: colors.background, shape: BoxShape.circle),
                child: Icon(icon, size: 34, color: colors.foreground),
              ),
              const SizedBox(height: 20),
              Text(title, textAlign: TextAlign.center, style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(message, textAlign: TextAlign.center, style: theme.textTheme.bodyLarge?.copyWith(color: AppColors.muted)),
              if (action != null) ...[const SizedBox(height: 24), action!],
            ],
          ),
        ),
      ),
    );
  }
}

class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return MessageView(
      icon: Icons.cloud_off_rounded,
      tone: Tone.danger,
      title: 'Chargement impossible',
      message: errorText(error),
      action: OutlinedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh_rounded), label: const Text('Réessayer')),
    );
  }
}

String errorText(Object error) =>
    error is ApiException ? error.displayMessage : "Une erreur inattendue s'est produite. Réessayez.";

void showError(BuildContext context, Object error) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(errorText(error)), backgroundColor: AppColors.chili));
}

void showDone(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(confirmLabel)),
      ],
    ),
  );
  return confirmed ?? false;
}
