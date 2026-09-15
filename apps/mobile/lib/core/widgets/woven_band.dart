import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme.dart';

class WeaveSegment {
  const WeaveSegment({required this.fill, this.color = AppColors.leaf, this.highlight = false});

  /// Part payée, de 0 à 1.
  final double fill;
  final Color color;

  /// Liseré or : tour en cours ou tour où le membre reçoit.
  final bool highlight;

  @override
  bool operator ==(Object other) =>
      other is WeaveSegment && other.fill == fill && other.color == color && other.highlight == highlight;

  @override
  int get hashCode => Object.hash(fill, color, highlight);
}

/// Répartit un taux global (0 à 1) sur [count] cases remplies les unes après les autres.
List<WeaveSegment> progressSegments(double ratio, int count, {Color color = AppColors.leaf}) {
  final filledUnits = ratio.clamp(0.0, 1.0) * count;
  return [for (var i = 0; i < count; i++) WeaveSegment(fill: (filledUnits - i).clamp(0.0, 1.0), color: color)];
}

/// Bande tissée : une case par tour, remplie selon les cotisations payées.
/// La trame diagonale rappelle les rayures du Faso Dan Fani.
class WovenBand extends StatelessWidget {
  const WovenBand({super.key, required this.segments, this.height = 14, required this.semanticLabel});

  final List<WeaveSegment> segments;
  final double height;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final animate = !MediaQuery.disableAnimationsOf(context);

    return Semantics(
      label: semanticLabel,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: animate ? 0 : 1, end: 1),
        duration: animate ? const Duration(milliseconds: 700) : Duration.zero,
        curve: Curves.easeOutCubic,
        builder: (context, progress, _) => SizedBox(
          height: height,
          width: double.infinity,
          child: CustomPaint(painter: _WovenBandPainter(segments, progress)),
        ),
      ),
    );
  }
}

class _WovenBandPainter extends CustomPainter {
  _WovenBandPainter(this.segments, this.progress);

  final List<WeaveSegment> segments;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (segments.isEmpty || size.width <= 0) return;

    var cells = segments;
    var gap = cells.length > 24 ? 1.5 : 3.0;
    var width = (size.width - gap * (cells.length - 1)) / cells.length;

    // Trop de tours pour la largeur disponible : une seule bande avec la moyenne.
    if (width < 3) {
      final average = cells.fold<double>(0, (sum, cell) => sum + cell.fill.clamp(0.0, 1.0)) / cells.length;
      cells = [WeaveSegment(fill: average)];
      gap = 0;
      width = size.width;
    }

    final radius = Radius.circular(math.min(size.height / 2, 4));
    final basePaint = Paint()..color = AppColors.line;
    final stripePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.22)
      ..strokeWidth = 2;

    for (var index = 0; index < cells.length; index++) {
      final cell = cells[index];
      final left = index * (width + gap);
      final shape = RRect.fromRectAndRadius(Rect.fromLTWH(left, 0, width, size.height), radius);

      canvas.drawRRect(shape, basePaint);

      final fill = cell.fill.clamp(0.0, 1.0) * progress;
      if (fill > 0) {
        final filled = Rect.fromLTWH(left, 0, width * fill, size.height);
        canvas
          ..save()
          ..clipRRect(shape)
          ..clipRect(filled)
          ..drawRect(filled, Paint()..color = cell.color);
        for (var x = left - size.height; x < left + width; x += 6) {
          canvas.drawLine(Offset(x, size.height), Offset(x + size.height, 0), stripePaint);
        }
        canvas.restore();
      }

      if (cell.highlight) {
        canvas.drawRRect(
          shape.deflate(1),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = AppColors.gold,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_WovenBandPainter oldDelegate) =>
      oldDelegate.progress != progress || !_sameSegments(oldDelegate.segments, segments);

  static bool _sameSegments(List<WeaveSegment> a, List<WeaveSegment> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
