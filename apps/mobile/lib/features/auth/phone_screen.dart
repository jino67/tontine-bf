import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme.dart';
import '../../core/api/api_exception.dart';
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
  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  final _formKey = GlobalKey<FormState>();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  bool _sending = false;

  /// Vrai quand l'API demande une adresse : première connexion, le code part par e-mail.
  bool _askEmail = false;
  String? _emailError;

  @override
  void dispose() {
    _phone.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final phone = normalizeBurkinaPhone(_phone.text)!;
    final email = _askEmail ? _email.text.trim() : null;
    final session = SessionScope.read(context);

    setState(() {
      _sending = true;
      _emailError = null;
    });
    try {
      final delivery = await session.auth.requestOtp(phone, email: email);
      if (!mounted) return;
      setState(() => _sending = false);
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => OtpScreen(phone: phone, email: email, delivery: delivery)));
    } on ApiException catch (error) {
      if (!mounted) return;
      final emailError = error.fieldError('email');
      setState(() {
        _sending = false;
        if (emailError != null) {
          // La première fois, l'API demande simplement l'adresse : ce n'est pas une erreur à afficher.
          _emailError = _askEmail ? emailError : null;
          _askEmail = true;
        }
      });
      if (emailError == null) showError(context, error);
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
                  'Nous vous envoyons un code de connexion. Pas de mot de passe à retenir.',
                  style: theme.textTheme.bodyLarge?.copyWith(color: AppColors.muted),
                ),
                const SizedBox(height: 28),
                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: _phone,
                        keyboardType: TextInputType.phone,
                        autofillHints: const [AutofillHints.telephoneNumber],
                        textInputAction: _askEmail ? TextInputAction.next : TextInputAction.done,
                        onFieldSubmitted: (_) {
                          if (!_askEmail) _submit();
                        },
                        onChanged: (_) {
                          // Un autre numéro a peut-être déjà une adresse liée : l'API redemandera si besoin.
                          if (_askEmail) {
                            setState(() {
                              _askEmail = false;
                              _emailError = null;
                            });
                          }
                        },
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9 +]'))],
                        style: AppType.code(22, letterSpacing: 1.5),
                        decoration: const InputDecoration(labelText: 'Numéro', hintText: '70 12 34 56', prefixText: '+226  '),
                        validator: (value) =>
                            normalizeBurkinaPhone(value ?? '') == null ? 'Saisissez les 8 chiffres de votre numéro.' : null,
                      ),
                      if (_askEmail) ...[
                        const SizedBox(height: 20),
                        Text(
                          'Première connexion : indiquez votre adresse e-mail. Le code y sera envoyé, '
                          'et l’adresse restera liée à votre numéro.',
                          style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.muted),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _email,
                          autofocus: true,
                          autocorrect: false,
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [AutofillHints.email],
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _submit(),
                          decoration: InputDecoration(
                            labelText: 'Adresse e-mail',
                            hintText: 'nom@exemple.com',
                            errorText: _emailError,
                          ),
                          validator: (value) =>
                              _emailPattern.hasMatch((value ?? '').trim()) ? null : 'Saisissez une adresse e-mail valide.',
                        ),
                      ],
                    ],
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
