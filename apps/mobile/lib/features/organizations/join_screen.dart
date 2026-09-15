import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme.dart';
import '../../core/api/api_exception.dart';
import '../../core/session/session_scope.dart';
import '../../core/widgets/brand.dart';
import '../../core/widgets/ui.dart';

class JoinScreen extends StatefulWidget {
  const JoinScreen({super.key});

  @override
  State<JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends State<JoinScreen> {
  final _code = TextEditingController();
  bool _joining = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    final code = _code.text.trim();
    if (code.length != 8) {
      setState(() => _error = 'Le code contient 8 lettres et chiffres.');
      return;
    }

    final session = SessionScope.read(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    setState(() {
      _joining = true;
      _error = null;
    });
    try {
      final result = await session.organizations.acceptInvitation(code);
      if (navigator.canPop()) navigator.pop();
      await session.reloadOrganizations(select: result.organization.id);
      final tontine = result.tontineName == null ? '' : ' et à la tontine ${result.tontineName}';
      messenger.showSnackBar(SnackBar(content: Text('Bienvenue dans ${result.organization.name}$tontine.')));
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _joining = false;
        _error = error.displayMessage;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Rejoindre')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(color: AppColors.goldSoft, shape: BoxShape.circle),
              child: const Icon(Icons.key_rounded, color: AppColors.goldText, size: 30),
            ),
            const SizedBox(height: 20),
            Text('Code d’invitation', style: theme.textTheme.headlineMedium),
            const SizedBox(height: 10),
            Text(
              'Le responsable de votre groupe vous l’a transmis, par exemple par WhatsApp. '
              'Il contient 8 lettres et chiffres.',
              style: theme.textTheme.bodyLarge?.copyWith(color: AppColors.muted),
            ),
            const SizedBox(height: 28),
            TextField(
              controller: _code,
              autofocus: true,
              maxLength: 8,
              textAlign: TextAlign.center,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]')),
                const _UpperCaseFormatter(),
              ],
              style: AppType.code(28),
              decoration: InputDecoration(counterText: '', hintText: 'ABCD2345', errorText: _error, errorMaxLines: 3),
              onSubmitted: (_) => _join(),
            ),
            const SizedBox(height: 20),
            FilledButton(onPressed: _joining ? null : _join, child: _joining ? const ButtonSpinner() : const Text('Rejoindre')),
            const SizedBox(height: 24),
            Panel(
              color: AppColors.cotton,
              child: Text(
                'Si le code vise une tontine, vous y êtes inscrit en même temps. '
                'Les inscriptions se ferment quand la tontine démarre.',
                style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.muted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UpperCaseFormatter extends TextInputFormatter {
  const _UpperCaseFormatter();

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) =>
      newValue.copyWith(text: newValue.text.toUpperCase());
}
