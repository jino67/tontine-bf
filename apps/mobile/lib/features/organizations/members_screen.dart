import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/format.dart';
import '../../core/session/session_scope.dart';
import '../../core/widgets/ui.dart';
import 'invite_sheet.dart';
import 'organization.dart';

class MembersScreen extends StatefulWidget {
  const MembersScreen({super.key});

  @override
  State<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends State<MembersScreen> {
  late Future<List<Membership>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Membership>> _load() {
    final session = SessionScope.read(context);
    return session.organizations.members(session.currentOrganization!.id);
  }

  Future<void> _refresh() async {
    final future = _load();
    setState(() => _future = future);
    try {
      await future;
    } catch (_) {
      // L'erreur est affichée à l'écran.
    }
  }

  Future<void> _changeRole(Membership membership) async {
    final session = SessionScope.read(context);
    final role = await showModalBottomSheet<Role>(
      context: context,
      builder: (context) => _RolePicker(current: membership.role, name: membership.user.displayName),
    );
    if (role == null || role == membership.role || !mounted) return;

    try {
      await session.organizations.updateRole(session.currentOrganization!.id, membership.id, role);
      if (!mounted) return;
      showDone(context, '${membership.user.displayName} est maintenant ${role.label.toLowerCase()}');
      await _refresh();
    } catch (error) {
      if (mounted) showError(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    final organization = session.currentOrganization!;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Membres et rôles'),
        actions: [
          if (organization.role.canManage)
            IconButton(
              tooltip: 'Inviter dans l’organisation',
              onPressed: () => showInviteSheet(context, organization: organization),
              icon: const Icon(Icons.person_add_alt_1_rounded),
            ),
        ],
      ),
      body: FutureBuilder<List<Membership>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.hasError && !snapshot.hasData) return ErrorView(error: snapshot.error!, onRetry: _refresh);
          if (!snapshot.hasData) return const LoadingView();

          final members = snapshot.requireData;
          final groups = <(String, List<Membership>)>[
            ('Responsables', members.where((m) => m.role.canManage).toList()),
            ('Trésorerie', members.where((m) => m.role == Role.treasurer).toList()),
            ('Membres', members.where((m) => m.role == Role.member).toList()),
          ];

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 32),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                  child: Text(
                    '${countLabel(members.length, 'personne', 'personnes')} dans ${organization.name}.'
                    '${organization.role == Role.owner ? ' Touchez un membre pour changer son rôle.' : ''}',
                    style: theme.textTheme.bodyLarge?.copyWith(color: AppColors.muted),
                  ),
                ),
                for (final (title, list) in groups)
                  if (list.isNotEmpty) ...[
                    SectionTitle(title),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Card(
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          children: [
                            for (var i = 0; i < list.length; i++) ...[
                              if (i > 0) const Divider(indent: 72),
                              _MemberRow(
                                membership: list[i],
                                isMe: list[i].user.id == session.user?.id,
                                onTap: organization.role == Role.owner &&
                                        list[i].role != Role.owner &&
                                        list[i].user.id != session.user?.id
                                    ? () => _changeRole(list[i])
                                    : null,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({required this.membership, required this.isMe, this.onTap});

  final Membership membership;
  final bool isMe;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tone = switch (membership.role) {
      Role.owner => Tone.gold,
      Role.admin => Tone.positive,
      Role.treasurer => Tone.indigo,
      Role.member => Tone.neutral,
    };

    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: MemberAvatar(name: membership.user.name),
      title: Text(isMe ? '${membership.user.displayName} (vous)' : membership.user.displayName),
      subtitle: Text(phoneDisplay(membership.user.phone)),
      trailing: StatusPill(label: membership.role.label, tone: tone),
    );
  }
}

class _RolePicker extends StatelessWidget {
  const _RolePicker({required this.current, required this.name});

  final Role current;
  final String name;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Text('Rôle de $name', style: theme.textTheme.titleLarge),
          ),
          for (final role in [Role.admin, Role.treasurer, Role.member])
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 24),
              leading: Icon(
                role == current ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                color: role == current ? AppColors.leaf : AppColors.muted,
              ),
              title: Text(role.label),
              subtitle: Text(role.description),
              onTap: () => Navigator.of(context).pop(role),
            ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
