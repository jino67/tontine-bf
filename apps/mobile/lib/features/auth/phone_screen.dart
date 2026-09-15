import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme.dart';
import '../../core/format.dart';
import '../../core/session/session_scope.dart';
import '../../core/widgets/brand.dart';
import '../../core/widgets/ui.dart';
import '../profile/legal_screens.dart';
import 'otp_screen.dart';

class PhoneScreen extends StatefulWidget {
  const PhoneScreen({super.key});

  @override
  State<PhoneScreen> createState() => _PhoneScreenState();
}

class _PhoneScreenState extends State<PhoneScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phone = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final phone = normalizeBurkinaPhone(_phone.text)!;
    final session = SessionScope.read(context);

    setState(() => _sending = true);
    try {
      await session.auth.requestOtp(phone);
      if (!mounted) return;
      setState(() => _sending = false);
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => OtpScreen(phone: phone)));
    } catch (error) {
      if (!mounted) return;
      setState(() => _sending = false);
      showError(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Row(
                  children: [
                    const AppLogo(),
                    const SizedBox(width: 12),
                    Text('Tontine BF', style: theme.textTheme.titleLarge),
                  ],
                ),
                const SizedBox(height: 48),
                Text('Votre numéro de téléphone', style: theme.textTheme.headlineMedium),
                const SizedBox(height: 10),
                Text(
                  'Nous vous envoyons un code par SMS. Pas de mot de passe à retenir.',
                  style: theme.textTheme.bodyLarge?.copyWith(color: AppColors.muted),
                ),
                const SizedBox(height: 28),
                Form(
                  key: _formKey,
                  child: TextFormField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    autofillHints: const [AutofillHints.telephoneNumber],
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _submit(),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9 +]'))],
                    style: AppType.code(22, letterSpacing: 1.5),
                    decoration: const InputDecoration(labelText: 'Numéro', hintText: '70 12 34 56', prefixText: '+226  '),
                    validator: (value) =>
                        normalizeBurkinaPhone(value ?? '') == null ? 'Saisissez les 8 chiffres de votre numéro.' : null,
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _sending ? null : _submit,
                  child: _sending ? const ButtonSpinner() : const Text('Recevoir le code'),
                ),
                const SizedBox(height: 36),
                Text(
                  'Votre numéro sert uniquement à vous identifier auprès de votre organisation.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.muted),
                ),
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PrivacyScreen())),
                    child: const Text('Lire la confidentialité'),
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
