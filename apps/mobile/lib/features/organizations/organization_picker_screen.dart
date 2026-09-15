import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/session/session_scope.dart';
import '../../core/widgets/brand.dart';
import '../../core/widgets/ui.dart';
import 'join_screen.dart';

class OrganizationPickerScreen extends StatelessWidget {
  const OrganizationPickerScreen({super.key});

  Future<void> _create(BuildContext context) async {
    final session = SessionScope.read(context);
    final name = await showDialog<String>(context: context, builder: (_) => const _CreateOrganizationDialog());
    if (name == null || !context.mounted) return;

    try {
      final organization = await session.organizations.create(name);
      await session.reloadOrganizations(select: organization.id);
    } catch (error) {
      if (context.mounted) showError(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    final theme = Theme.of(context);
    final organizations = session.organizationList;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vos organisations'),
        actions: [
          IconButton(
            tooltip: 'Se déconnecter',
            onPressed: session.signOut,
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: session.reloadOrganizations,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Text('Bonjour ${session.user?.firstName ?? ''}', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              organizations.isEmpty
                  ? 'Vous ne faites encore partie d’aucune organisation. Rejoignez celle de votre groupe avec le code '
                      'reçu du responsable, ou créez la vôtre.'
                  : 'Choisissez l’organisation à ouvrir.',
              style: theme.textTheme.bodyLarge?.copyWith(color: AppColors.muted),
            ),
            const SizedBox(height: 20),
            for (final organization in organizations) ...[
              Card(
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  leading: MemberAvatar(name: organization.name, size: 44),
                  title: Text(organization.name, style: theme.textTheme.titleMedium),
                  subtitle: Text(organization.role.label),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => session.selectOrganization(organization),
                ),
              ),
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const JoinScreen())),
              icon: const Icon(Icons.key_rounded),
              label: const Text('Rejoindre avec un code'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _create(context),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Créer une organisation'),
            ),
            if (organizations.isEmpty) ...[
              const SizedBox(height: 28),
              Text(
                'Créer une organisation vous en rend propriétaire : vous pourrez ensuite créer des tontines et inviter vos membres.',
                style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.muted),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CreateOrganizationDialog extends StatefulWidget {
  const _CreateOrganizationDialog();

  @override
  State<_CreateOrganizationDialog> createState() => _CreateOrganizationDialogState();
}

class _CreateOrganizationDialogState extends State<_CreateOrganizationDialog> {
  final _name = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _name.text.trim();
    if (name.length < 3) {
      setState(() => _error = 'Le nom doit contenir au moins 3 caractères.');
      return;
    }
    Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nouvelle organisation'),
      content: TextField(
        controller: _name,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        onSubmitted: (_) => _submit(),
        decoration: InputDecoration(
          labelText: 'Nom',
          hintText: 'Groupement Wend Panga',
          errorText: _error,
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Annuler')),
        FilledButton(onPressed: _submit, style: CompactButtons.filled, child: const Text('Créer')),
      ],
    );
  }
}