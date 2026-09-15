import 'package:flutter/material.dart';
import 'package:app_tontine_bf/screens/auth/login_screen.dart';
import 'package:app_tontine_bf/screens/tontine/create_tontine_advanced_screen.dart';
import 'package:app_tontine_bf/screens/tontine/tontine_detail_screen.dart';
// import 'package:app_tontine_bf/screens/community/forum_screen.dart';
import 'package:app_tontine_bf/screens/community/messages_screen.dart';
import 'package:app_tontine_bf/screens/wallet/wallet_screen.dart';
import 'package:app_tontine_bf/services/auth_service.dart';
import 'package:app_tontine_bf/services/dashboard_service.dart';
import 'package:app_tontine_bf/models/tontine.dart';
import 'package:app_tontine_bf/config/theme.dart';
import 'package:app_tontine_bf/features/cagnotte/screens/cagnotte_list_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final AuthService _authService = AuthService();
  final DashboardService _dashboardService = DashboardService();

  List<Tontine> _userTontines = [];
  Map<String, dynamic> _stats = {};
  bool _isLoading = true;
  // String? _userId;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    try {
      final userId = await _authService.getUserId();
      if (userId == null) return;

      final statsFuture = _dashboardService.getDashboardStats(userId);
      final tontinesFuture = _dashboardService.getUserTontines(userId);

      final results = await Future.wait([statsFuture, tontinesFuture]);

      if (!mounted) return;

      setState(() {
        _stats = results[0] as Map<String, dynamic>? ?? {};
        _userTontines = results[1] as List<Tontine>? ?? [];
        _isLoading = false;
      });
    } catch (e) {
      // print('Error loading dashboard: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _stats = {};
        _userTontines = [];
      });
    }
  }

  Future<void> _signOut(BuildContext context) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Déconnexion'),
        content: const Text('Voulez-vous vraiment vous déconnecter ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              await _authService.logout();
              if (!mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const LoginScreen()),
                    (Route<dynamic> route) => false,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: tontinePrimaryColor,
            ),
            child: const Text('Déconnexion'),
          ),
        ],
      ),
    );
  }

  Future<void> _navigateToCreateTontine() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const CreateTontineAdvancedScreen()),
    );

    if (result == true) {
      if (mounted) {
        setState(() => _isLoading = true);
      }
      await _loadDashboardData();
    }
  }

  void _navigateToTontineDetail(Tontine tontine) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => TontineDetailScreen(tontine: tontine)),
    );
  }

  void _navigateToCagnottes() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const CagnotteListScreen()),
    );
  }

  double _safeGetDouble(Map<String, dynamic> map, String key, double defaultValue) {
    try {
      if (!map.containsKey(key)) return defaultValue;
      final value = map[key];
      if (value == null) return defaultValue;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? defaultValue;
      return defaultValue;
    } catch (e) {
      return defaultValue;
    }
  }

  int _safeGetInt(Map<String, dynamic> map, String key, int defaultValue) {
    try {
      if (!map.containsKey(key)) return defaultValue;
      final value = map[key];
      if (value == null) return defaultValue;
      if (value is int) return value;
      if (value is double) return value.toInt();
      if (value is String) return int.tryParse(value) ?? defaultValue;
      return defaultValue;
    } catch (e) {
      return defaultValue;
    }
  }

  Widget _buildStatsCard() {
    // Version ultra-sécurisée avec valeurs par défaut
    final balance = _safeGetDouble(_stats, 'balance', 0.0);
    final activeTontines = _safeGetInt(_stats, 'active_tontines', 0);
    final completedTontines = _safeGetInt(_stats, 'completed_tontines', 0);
    final monthlyContributions = _safeGetDouble(_stats, 'monthly_contributions', 0.0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [tontinePrimaryColor, tontinePrimaryDark],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppShadows.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Solde Total',
                style: TextStyle(
                  fontSize: 16,
                  color: tontineWhite.withOpacity(0.9),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: tontineWhite.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_userTontines.length} Tontines',
                  style: TextStyle(
                    fontSize: 12,
                    color: tontineWhite,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '${balance.toStringAsFixed(0)} FCFA',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: tontineWhite,
            ),
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              _buildMiniStat('Actives', activeTontines.toString(), tontineAccentColor),
              const SizedBox(width: 20),
              _buildMiniStat('Terminées', completedTontines.toString(), tontineGold),
              const SizedBox(width: 20),
              _buildMiniStat('Mensuel', '${monthlyContributions.toStringAsFixed(0)} FCFA', tontineWhite),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: tontineWhite.withOpacity(0.8),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildTontineCard(Tontine tontine) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    tontine.nom,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: tontine.isActive
                        ? tontineAccentColor.withOpacity(0.2)
                        : tontinePrimaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    tontine.statusString,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: tontine.isActive ? tontineAccentDark : tontinePrimaryColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              tontine.typeString,
              style: AppTextStyles.bodyMedium,
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${tontine.montantCotisation.toStringAsFixed(0)} FCFA',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: tontineTextColor,
                      ),
                    ),
                    Text(
                      '${tontine.participants.length} membres',
                      style: AppTextStyles.bodyMedium,
                    ),
                  ],
                ),
                Container(
                  width: 60,
                  height: 60,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: tontinePrimaryColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Stack(
                    children: [
                      CircularProgressIndicator(
                        value: tontine.progressPercentage,
                        backgroundColor: tontineBackgroundColor,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          tontine.isActive ? tontinePrimaryColor : tontineAccentDark,
                        ),
                        strokeWidth: 4,
                      ),
                      Center(
                        child: Text(
                          '${(tontine.progressPercentage * 100).toInt()}%',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: tontinePrimaryColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _navigateToTontineDetail(tontine),
                style: ElevatedButton.styleFrom(
                  backgroundColor: tontinePrimaryColor.withOpacity(0.1),
                  foregroundColor: tontinePrimaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Voir Détails',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Actions Rapides',
          style: AppTextStyles.titleMedium,
        ),
        const SizedBox(height: 15),
        Row(
          children: [
            Expanded(
              child: _buildActionButton(
                'Nouvelle Tontine',
                Icons.add_circle_outline,
                tontinePrimaryColor,
                _navigateToCreateTontine,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionButton(
                'Portefeuille',
                Icons.account_balance_wallet,
                tontineAccentDark,
                    () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => const WalletScreen()),
                  );
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildActionButton(
                'Messages',
                Icons.message,
                tontinePrimaryDark,
                    () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => const MessagesScreen()),
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionButton(
                'Cagnottes',
                Icons.celebration,
                tontineGold,
                _navigateToCagnottes,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButton(String text, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCagnottesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Cagnottes en cours',
                style: AppTextStyles.titleMedium,
              ),
              TextButton(
                onPressed: _navigateToCagnottes,
                child: Text(
                  'Voir tout',
                  style: TextStyle(
                    color: tontinePrimaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Widget pour afficher les cagnottes
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: tontineWhite,
            borderRadius: BorderRadius.circular(16),
            boxShadow: AppShadows.cardShadow,
          ),
          child: Column(
            children: [
              ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: tontinePrimaryColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.celebration,
                    color: tontinePrimaryColor,
                    size: 20,
                  ),
                ),
                title: const Text(
                  'Cagnotte Flash Quotidienne',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  'Se termine dans 4h • 3 500 FCFA',
                  style: TextStyle(
                    color: tontineTextLight,
                  ),
                ),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: tontineAccentColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Participer',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: tontineWhite,
                    ),
                  ),
                ),
                onTap: _navigateToCagnottes,
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: tontinePrimaryDark.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.celebration,
                    color: tontinePrimaryDark,
                    size: 20,
                  ),
                ),
                title: const Text(
                  'Cagnotte Hebdomadaire',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  'Se termine dans 2j • 12 000 FCFA',
                  style: TextStyle(
                    color: tontineTextLight,
                  ),
                ),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: tontineAccentColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Participer',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: tontineWhite,
                    ),
                  ),
                ),
                onTap: _navigateToCagnottes,
              ),
              const SizedBox(height: 8),
              Text(
                'Participez aux cagnottes et tentez de gagner !',
                style: TextStyle(
                  fontSize: 12,
                  color: tontineTextLight,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _navigateToCagnottes,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: tontinePrimaryColor,
                  ),
                  child: const Text('Découvrir toutes les cagnottes'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.group_off,
              size: 80,
              color: tontineTextLight.withOpacity(0.3),
            ),
            const SizedBox(height: 20),
            Text(
              'Aucune tontine',
              style: AppTextStyles.titleMedium.copyWith(
                color: tontineTextLight,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Commencez par créer votre première tontine',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium,
            ),
            const SizedBox(height: 25),
            ElevatedButton(
              onPressed: _navigateToCreateTontine,
              style: ElevatedButton.styleFrom(
                backgroundColor: tontinePrimaryColor,
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
              ),
              child: const Text(
                'Créer ma première tontine',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: tontineBackgroundColor,
      appBar: AppBar(
        // CORRECTION FINALE : Utilisation de logo.png
        title: Image.asset(
          'assets/images/logo.png', // Chemin corrigé pour correspondre à votre fichier
          height: 35,
          fit: BoxFit.contain,
        ),
        centerTitle: false,
        backgroundColor: tontinePrimaryColor,
        actions: [
          IconButton(
            icon: const Icon(Icons.account_balance_wallet, color: tontineWhite),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const WalletScreen()),
              );
            },
            tooltip: 'Portefeuille',
          ),
          IconButton(
            icon: const Icon(Icons.message, color: tontineWhite),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const MessagesScreen()),
              );
            },
            tooltip: 'Messages',
          ),
          IconButton(
            icon: const Icon(Icons.celebration, color: tontineWhite),
            onPressed: _navigateToCagnottes,
            tooltip: 'Cagnottes',
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline, color: tontineWhite),
            onPressed: _navigateToCreateTontine,
            tooltip: 'Créer une tontine',
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: tontineWhite),
            onPressed: () => _signOut(context),
            tooltip: 'Déconnexion',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(tontinePrimaryColor),
            ),
            SizedBox(height: 16),
            Text(
              'Chargement des données...',
              style: AppTextStyles.bodyMedium,
            ),
          ],
        ),
      )
          : RefreshIndicator(
        onRefresh: _loadDashboardData,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Carte de statistiques
              _buildStatsCard(),
              const SizedBox(height: 25),

              // Actions rapides
              _buildQuickActions(),
              const SizedBox(height: 25),

              // Section Cagnottes
              _buildCagnottesSection(),
              const SizedBox(height: 25),

              // En-tête des tontines
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Mes Tontines',
                    style: AppTextStyles.titleMedium,
                  ),
                  Text(
                    '${_userTontines.length} tontines',
                    style: AppTextStyles.bodyMedium,
                  ),
                ],
              ),
              const SizedBox(height: 15),

              // Liste des tontines
              _userTontines.isEmpty
                  ? _buildEmptyState()
                  : Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.5,
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: _userTontines.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildTontineCard(_userTontines[index]),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToCreateTontine,
        backgroundColor: tontinePrimaryColor,
        foregroundColor: tontineWhite,
        child: const Icon(Icons.add),
      ),
    );
  }
}