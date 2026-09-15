import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme.dart';
import '../../core/api/api_exception.dart';
import '../../core/format.dart';
import '../../core/session/session_scope.dart';
import '../../core/widgets/brand.dart';
import '../../core/widgets/ui.dart';

class OtpScreen extends StatefulWidget {
  const OtpScreen({super.key, required this.phone});

  final String phone;

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  static const _resendDelay = 60;

  final _code = TextEditingController();
  Timer? _timer;
  int _secondsLeft = _resendDelay;
  bool _verifying = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    super.dispose();
  }

  void _startCountdown() {
    _timer?.cancel();
    setState(() => _secondsLeft = _resendDelay);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) timer.cancel();
    });
  }

  Future<void> _verify() async {
    if (_code.text.length != 6 || _verifying) {
      setState(() => _error = 'Le code contient 6 chiffres.');
      return;
    }
    final session = SessionScope.read(context);

    setState(() {
      _verifying = true;
      _error = null;
    });
    try {
      await session.signIn(phone: widget.phone, code: _code.text);
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _verifying = false;
        _error = error.fieldError('code') ?? error.displayMessage;
      });
    }
  }

  Future<void> _resend() async {
    final session = SessionScope.read(context);
    try {
      await session.auth.requestOtp(widget.phone);
      if (!mounted) return;
      _startCountdown();
      showDone(context, 'Nouveau code envoyé');
    } catch (error) {
      if (mounted) showError(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              children: [
                Text('Code de connexion', style: theme.textTheme.headlineMedium),
                const SizedBox(height: 10),
                Text(
                  'Saisissez le code à 6 chiffres envoyé par SMS au ${phoneDisplay(widget.phone)}.',
                  style: theme.textTheme.bodyLarge?.copyWith(color: AppColors.muted),
                ),
                const SizedBox(height: 28),
                TextField(
                  controller: _code,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: AppType.code(34, letterSpacing: 14),
                  decoration: InputDecoration(counterText: '', hintText: '000000', errorText: _error, errorMaxLines: 3),
                  onChanged: (value) {
                    if (_error != null) setState(() => _error = null);
                    if (value.length == 6) _verify();
                  },
                ),
                if (kDebugMode) ...[
                  const SizedBox(height: 12),
                  Panel(
                    color: AppColors.indigoSoft,
                    borderColor: AppColors.indigoSoft,
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      'Mode développement : le code est écrit dans apps/api/storage/logs/laravel.log.',
                      style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.indigo),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _verifying ? null : _verify,
                  child: _verifying ? const ButtonSpinner() : const Text('Se connecter'),
                ),
                const SizedBox(height: 12),
                Center(
                  child: TextButton(
                    onPressed: _secondsLeft > 0 ? null : _resend,
                    child: Text(_secondsLeft > 0 ? 'Renvoyer le code dans $_secondsLeft s' : 'Renvoyer le code'),
                  ),
                ),
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Changer de numéro'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
