import 'package:flutter/material.dart';

import '../../app/config.dart';
import '../../app/theme.dart';
import '../../core/format.dart';
import '../../core/session/session_controller.dart';
import '../../core/session/session_scope.dart';
import '../../core/widgets/brand.dart';
import '../../core/widgets/ui.dart';
import '../organizations/invite_sheet.dart';
import '../organizations/join_screen.dart';
import '../organizations/members_screen.dart';
import 'guide_screen.dart';
import 'help_screen.dart';
import 'legal_screens.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _editProfile(BuildContext context, SessionController session) async {
    final result = await showDialog<({String name, String? email})>(
      context: context,
      builder: (_) => _ProfileDialog(name: session.user?.name ?? '', email: session.user?.email ?? ''),
    );
    if (result == null || !context.mounted) return;

    try {
      await session.updateProfile(name: result.name, email: result.email);
      if (context.mounted) showDone(context, 'Profil mis à jour');
    } catch (error) {
      if (context.mounted) showError(context, error);
    }
  }

  Future<void> _signOut(BuildContext context, SessionController session) async {
    final confirmed = await confirmAction(
      context,
      title: 'Se déconnecter ?',
      message: 'Vous devrez saisir un nouveau code reçu par SMS pour vous reconnecter.',
      confirmLabel: 'Se déconnecter',
    );
    if (confirmed) await session.signOut();
  }

  void _open(BuildContext context, Widget screen) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    final user = session.user;
    final organization = session.currentOrganization!;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 12, 0),
            child: Row(
              children: [
                MemberAvatar(name: user?.name, size: 64, tone: Tone.gold),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user?.name ?? 'Sans nom', style: theme.textTheme.headlineSmall),
                      Text(phoneDisplay(user?.phone ?? ''), style: theme.textTheme.bodyLarge?.copyWith(color: AppColors.muted)),
                      if (user?.email != null)
                        Text(user!.email!, style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.muted)),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Modifier mon profil',
                  onPressed: () => _editProfile(context, session),
                  icon: const Icon(Icons.edit_outlined),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Panel(
              radius: 20,
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(organization.name, style: theme.textTheme.titleLarge),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      StatusPill(label: organization.role.label, tone: Tone.gold),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          organization.role.description,
                          style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.muted),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  OutlinedButton(
                    onPressed: session.switchOrganization,
                    style: CompactButtons.outlined,
                    child: const Text('Changer d’organisation'),
                  ),
                ],
              ),
            ),
          ),
          const SectionTitle('Organisation'),
          _LinkGroup(
            links: [
              _Link(Icons.groups_outlined, 'Membres et rôles', () => _open(context, const MembersScreen())),
              if (organization.role.canManage)
                _Link(
                  Icons.person_add_alt_1_outlined,
                  'Inviter dans l’organisation',
                  () => showInviteSheet(context, organization: organization),
                ),
              _Link(Icons.key_outlined, 'Rejoindre une autre organisation', () => _open(context, const JoinScreen())),
            ],
          ),
          const SectionTitle('Aide'),
          _LinkGroup(
            links: [
              _Link(Icons.help_outline_rounded, 'Questions fréquentes', () => _open(context, const HelpScreen())),
              _Link(Icons.menu_book_outlined, 'Comprendre les types de tontine', () => _open(context, const GuideScreen())),
              _Link(Icons.shield_outlined, 'Confidentialité', () => _open(context, const PrivacyScreen())),
              _Link(Icons.info_outline_rounded, 'À propos de Tontine BF', () => _open(context, const AboutScreen())),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
            child: OutlinedButton.icon(
              onPressed: () => _signOut(context, session),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.chili,
                side: const BorderSide(color: AppColors.chiliSoft, width: 1.5),
              ),
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Se déconnecter'),
            ),
          ),
          const SizedBox(height: 16),
          Text('Version ${AppConfig.version}', textAlign: TextAlign.center, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _Link {
  const _Link(this.icon, this.label, this.onTap);

  final IconData icon;
  final String label;
  final VoidCallback onTap;
}

class _LinkGroup extends StatelessWidget {
  const _LinkGroup({required this.links});

  final List<_Link> links;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            for (var i = 0; i < links.length; i++) ...[
              if (i > 0) const Divider(indent: 56),
              ListTile(
                leading: Icon(links[i].icon),
                title: Text(links[i].label),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: links[i].onTap,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProfileDialog extends StatefulWidget {
  const _ProfileDialog({required this.name, required this.email});

  final String name;
  final String email;

  @override
  State<_ProfileDialog> createState() => _ProfileDialogState();
}

class _ProfileDialogState extends State<_ProfileDialog> {
  late final _name = TextEditingController(text: widget.name);
  late final _email = TextEditingController(text: widget.email);
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    super.dispose();
  }

  void _save() {
    final name = _name.text.trim();
    if (name.length < 2) {
      setState(() => _error = 'Saisissez au moins 2 lettres.');
      return;
    }
    final email = _email.text.trim();
    Navigator.of(context).pop((name: name, email: email.isEmpty ? null : email));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Modifier mon profil'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(labelText: 'Prénom et nom', errorText: _error),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'E-mail (facultatif)'),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Annuler')),
        FilledButton(onPressed: _save, style: CompactButtons.filled, child: const Text('Enregistrer')),
      ],
    );
  }
}
