import 'package:flutter/material.dart';

import '../../app/theme.dart';

class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 44});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(size * 0.28)),
      child: Image.asset(
        'assets/images/logo.png',
        fit: BoxFit.contain,
        semanticLabel: 'Logo Tontine BF',
        errorBuilder: (context, error, stackTrace) => Icon(Icons.groups_rounded, color: AppColors.leaf, size: size * 0.6),
      ),
    );
  }
}

class ButtonSpinner extends StatelessWidget {
  const ButtonSpinner({super.key, this.color = Colors.white});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: color));
  }
}

/// Styles de boutons compacts utilisés dans les listes.
abstract final class CompactButtons {
  static final outlined = OutlinedButton.styleFrom(
    minimumSize: const Size(0, 40),
    padding: const EdgeInsets.symmetric(horizontal: 14),
    textStyle: AppType.sans(size: 14, bold: true),
  );

  static final filled = FilledButton.styleFrom(
    minimumSize: const Size(0, 40),
    padding: const EdgeInsets.symmetric(horizontal: 14),
    textStyle: AppType.sans(size: 14, bold: true),
  );
}
