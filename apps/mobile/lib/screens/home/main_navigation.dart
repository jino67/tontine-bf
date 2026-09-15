import 'package:flutter/material.dart';
import 'package:app_tontine_bf/config/theme.dart';
import 'package:app_tontine_bf/screens/home/dashboard_screen.dart';
import 'package:app_tontine_bf/features/cagnotte/screens/cagnotte_list_screen.dart';
import 'package:app_tontine_bf/screens/community/forum_screen.dart';
import 'package:app_tontine_bf/screens/community/messages_screen.dart';
import 'package:app_tontine_bf/screens/wallet/wallet_screen.dart';
import 'package:app_tontine_bf/features/cagnotte/screens/admin/admin_cagnotte_manage.dart';
import 'package:app_tontine_bf/services/auth_service.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;
  final AuthService _authService = AuthService();
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _checkAdminStatus();
  }

  Future<void> _checkAdminStatus() async {
    print('=== DEBUG MAIN NAVIGATION ===');
    final isAdmin = await _authService.isUserAdmin();
    print('isUserAdmin result: $isAdmin');

    final user = await _authService.getCurrentUser();
    print('Current user: $user');
    print('Current user isVerified: ${user?.isVerified}');

    if (mounted) {
      setState(() {
        _isAdmin = isAdmin;
      });
    }
    print('_isAdmin set to: $_isAdmin');
    print('=== END DEBUG ===');
  }

  // Utilise les écrans qui existent réellement dans ton projet
  final List<Widget> _screens = [
    const DashboardScreen(),
    const CagnotteListScreen(),
    const ForumScreen(),
    const MessagesScreen(),
    const WalletScreen(),
  ];

  final List<BottomNavigationBarItem> _bottomNavItems = [
    const BottomNavigationBarItem(
      icon: Icon(Icons.home),
      label: 'Accueil',
    ),
    const BottomNavigationBarItem(
      icon: Icon(Icons.celebration),
      label: 'Cagnottes',
    ),
    const BottomNavigationBarItem(
      icon: Icon(Icons.forum),
      label: 'Forum',
    ),
    const BottomNavigationBarItem(
      icon: Icon(Icons.message),
      label: 'Messages',
    ),
    const BottomNavigationBarItem(
      icon: Icon(Icons.account_balance_wallet),
      label: 'Portefeuille',
    ),
  ];

  void _navigateToAdmin() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AdminCagnotteManage(),
      ),
    );
  }

  void _onAddButtonPressed() {
    // Action pour le bouton +
    // Tu peux adapter cette action selon tes besoins
    print('Bouton + pressed');

    // Exemple : Afficher un menu d'actions possibles
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.celebration, color: tontinePrimaryColor),
              title: const Text('Créer une cagnotte'),
              onTap: () {
                Navigator.pop(context);
                // Naviguer vers création de cagnotte
              },
            ),
            ListTile(
              leading: Icon(Icons.people, color: tontinePrimaryColor),
              title: const Text('Créer une tontine'),
              onTap: () {
                Navigator.pop(context);
                // Naviguer vers création de tontine
              },
            ),
            ListTile(
              leading: Icon(Icons.forum, color: tontinePrimaryColor),
              title: const Text('Nouveau sujet de discussion'),
              onTap: () {
                Navigator.pop(context);
                // Naviguer vers création de forum
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: _bottomNavItems,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: tontinePrimaryColor,
        unselectedItemColor: tontineTextLight,
        backgroundColor: tontineWhite,
        elevation: 8,
        showSelectedLabels: true,
        showUnselectedLabels: true,
      ),

      // DEUX BOUTONS FLOATING : ADMIN ROUGE + BOUTON VERT
      floatingActionButton: _isAdmin
          ? Column(
        mainAxisAlignment: MainAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Bouton admin (rouge) - plus petit
          FloatingActionButton(
            onPressed: _navigateToAdmin,
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            mini: true, // Plus petit
            heroTag: "admin_btn", // Tag unique pour éviter les conflits
            child: const Icon(Icons.admin_panel_settings, size: 20),
            tooltip: 'Administration Cagnottes',
          ),
          const SizedBox(height: 12), // Espacement entre les boutons
          // Bouton + original (vert)
          FloatingActionButton(
            onPressed: _onAddButtonPressed,
            backgroundColor: tontinePrimaryColor,
            foregroundColor: Colors.white,
            heroTag: "add_btn", // Tag unique pour éviter les conflits
            child: const Icon(Icons.add),
            tooltip: 'Nouvelle action',
          ),
        ],
      )
          : // Si pas admin, seulement le bouton +
      FloatingActionButton(
        onPressed: _onAddButtonPressed,
        backgroundColor: tontinePrimaryColor,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
        tooltip: 'Nouvelle action',
      ),

      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}