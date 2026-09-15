import 'package:flutter/material.dart';

import '../core/session/session_scope.dart';
import '../features/home/dashboard_screen.dart';
import '../features/home/schedule_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/tontines/tontine_repository.dart';
import '../features/tontines/tontines_screen.dart';

/// Navigation principale d'une organisation : Accueil, Tontines, Échéances, Profil.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  TontineRepository? _repository;
  int _index = 0;

  /// Les onglets ne se chargent qu'à leur première ouverture.
  final _opened = <int>{0};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final session = SessionScope.read(context);
    _repository ??= TontineRepository(session.api, session.currentOrganization!.id);
  }

  void _select(int index) => setState(() {
        _index = index;
        _opened.add(index);
      });

  @override
  Widget build(BuildContext context) {
    final repository = _repository!;
    final pages = [
      DashboardScreen(repository: repository, onOpenTab: _select),
      TontinesScreen(repository: repository),
      ScheduleScreen(repository: repository),
      const ProfileScreen(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          for (var i = 0; i < pages.length; i++) _opened.contains(i) ? pages[i] : const SizedBox.shrink(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _select,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Accueil'),
          NavigationDestination(icon: Icon(Icons.groups_outlined), selectedIcon: Icon(Icons.groups_rounded), label: 'Tontines'),
          NavigationDestination(
            icon: Icon(Icons.event_note_outlined),
            selectedIcon: Icon(Icons.event_note_rounded),
            label: 'Échéances',
          ),
          NavigationDestination(icon: Icon(Icons.person_outline_rounded), selectedIcon: Icon(Icons.person_rounded), label: 'Profil'),
        ],
      ),
    );
  }
}
