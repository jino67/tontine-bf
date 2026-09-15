import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/session/session_scope.dart';
import '../../core/widgets/brand.dart';
import '../../core/widgets/ui.dart';

/// Demandé à la première connexion : le nom permet aux autres membres de vous reconnaître.
class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final session = SessionScope.read(context);
    setState(() => _saving = true);
    try {
      await session.updateProfile(name: _name.text.trim());
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
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
                const SizedBox(height: 24),
                ValueListenableBuilder(
                  valueListenable: _name,
                  builder: (context, value, _) => Align(
                    alignment: Alignment.centerLeft,
                    child: MemberAvatar(name: value.text, size: 72, tone: Tone.gold),
                  ),
                ),
                const SizedBox(height: 24),
                Text('Comment vous appelle-t-on ?', style: theme.textTheme.headlineMedium),
                const SizedBox(height: 10),
                Text(
                  'Votre nom apparaît dans les tontines, pour que le trésorier et les membres vous reconnaissent.',
                  style: theme.textTheme.bodyLarge?.copyWith(color: AppColors.muted),
                ),
                const SizedBox(height: 28),
                Form(
                  key: _formKey,
                  child: TextFormField(
                    controller: _name,
                    autofocus: true,
                    textCapitalization: TextCapitalization.words,
                    autofillHints: const [AutofillHints.name],
                    onFieldSubmitted: (_) => _save(),
                    decoration: const InputDecoration(labelText: 'Prénom et nom', hintText: 'Awa Ouédraogo'),
                    validator: (value) => (value ?? '').trim().length < 2 ? 'Saisissez au moins 2 lettres.' : null,
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton(onPressed: _saving ? null : _save, child: _saving ? const ButtonSpinner() : const Text('Continuer')),
                const SizedBox(height: 12),
                Center(
                  child: TextButton(
                    onPressed: () => SessionScope.read(context).signOut(),
                    child: const Text('Ce n’est pas mon numéro'),
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
