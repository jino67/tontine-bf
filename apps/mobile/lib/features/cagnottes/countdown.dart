import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/format.dart';

/// Temps restant avant la clôture, mis à jour chaque seconde.
class Countdown extends StatefulWidget {
  const Countdown({super.key, required this.deadline, this.style, this.onFinished});

  final DateTime deadline;
  final TextStyle? style;

  /// Appelé une fois, quand le temps est écoulé.
  final VoidCallback? onFinished;

  @override
  State<Countdown> createState() => _CountdownState();
}

class _CountdownState extends State<Countdown> {
  Timer? _timer;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void didUpdateWidget(Countdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.deadline != widget.deadline) {
      _timer?.cancel();
      _finished = false;
      _start();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _start() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (!_finished && !widget.deadline.isAfter(DateTime.now())) {
        _finished = true;
        _timer?.cancel();
        widget.onFinished?.call();
      }
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final left = widget.deadline.difference(DateTime.now());
    return Text(
      countdownLabel(left),
      semanticsLabel: 'Temps restant : ${countdownLabel(left)}',
      style: (widget.style ?? AppType.sans(bold: true)).copyWith(fontFeatures: AppType.tabularFigures),
    );
  }
}
