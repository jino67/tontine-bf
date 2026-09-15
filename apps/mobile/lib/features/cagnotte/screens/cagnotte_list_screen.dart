import 'package:flutter/material.dart';
import 'package:app_tontine_bf/config/theme.dart';
import 'package:app_tontine_bf/services/auth_service.dart';
import 'package:app_tontine_bf/features/cagnotte/services/cagnotte_service.dart';
import 'package:app_tontine_bf/features/cagnotte/models/cagnotte_model.dart';
import 'package:app_tontine_bf/features/cagnotte/widgets/cagnotte_card.dart';

class CagnotteListScreen extends StatefulWidget {
  const CagnotteListScreen({super.key});

  @override
  State<CagnotteListScreen> createState() => _CagnotteListScreenState();
}

class _CagnotteListScreenState extends State<CagnotteListScreen> {
  final CagnotteService _cagnotteService = CagnotteService();
  final AuthService _authService = AuthService();

  List<Cagnotte> _cagnottes = [];
  bool _isLoading = true;
  String? _errorMessage;
  String? _userId;

  @override
  void initState() {
    super.initState();
    _loadCagnottes();
  }

  Future<void> _loadCagnottes() async {
    try {
      final userId = await _authService.getUserId();
      if (userId == null) {
        setState(() {
          _errorMessage = 'Utilisateur non connecté';
          _isLoading = false;
        });
        return;
      }

      _userId = userId;
      final cagnottes = await _cagnotteService.getCagnottesList(userId);

      setState(() {
        _cagnottes = cagnottes;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Erreur de chargement: $e';
        _isLoading = false;
      });
    }
  }

  void _navigateToCagnotteDetail(Cagnotte cagnotte) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CagnotteDetailScreen(cagnotte: cagnotte),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [tontinePrimaryColor, tontinePrimaryDark],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Cagnottes Actives',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: tontineWhite,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Participez et tentez de gagner !',
            style: TextStyle(
              fontSize: 16,
              color: tontineWhite.withOpacity(0.9),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildStatItem('${_cagnottes.length}', 'Cagnottes', tontineAccentColor),
              const SizedBox(width: 20),
              _buildStatItem(
                  '${_cagnottes.where((c) => !c.dejaParticipe).length}',
                  'Nouvelles',
                  tontineWhite
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String value, String label, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: tontineWhite.withOpacity(0.8),
          ),
        ),
      ],
    );
  }

  Widget _buildCagnottesList() {
    if (_cagnottes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.celebration_outlined,
              size: 80,
              color: tontineTextLight.withOpacity(0.3),
            ),
            const SizedBox(height: 20),
            Text(
              'Aucune cagnotte active',
              style: TextStyle(
                fontSize: 18,
                color: tontineTextLight,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Revenez plus tard pour découvrir\nles nouvelles cagnottes',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: tontineTextLight.withOpacity(0.7),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _cagnottes.length,
      itemBuilder: (context, index) {
        final cagnotte = _cagnottes[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: CagnotteCard(
            cagnotte: cagnotte,
            onTap: () => _navigateToCagnotteDetail(cagnotte),
          ),
        );
      },
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(tontinePrimaryColor),
          ),
          const SizedBox(height: 16),
          Text(
            'Chargement des cagnottes...',
            style: TextStyle(
              color: tontineTextLight,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 80,
            color: tontineTextLight.withOpacity(0.3),
          ),
          const SizedBox(height: 20),
          Text(
            'Erreur de chargement',
            style: TextStyle(
              fontSize: 18,
              color: tontineTextLight,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _errorMessage ?? 'Une erreur est survenue',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: tontineTextLight.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _loadCagnottes,
            style: ElevatedButton.styleFrom(
              backgroundColor: tontinePrimaryColor,
            ),
            child: const Text('Réessayer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: tontineBackgroundColor,
      appBar: AppBar(
        title: const Text('Cagnottes'),
        backgroundColor: tontinePrimaryColor,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadCagnottes,
            tooltip: 'Actualiser',
          ),
        ],
      ),
      body: _isLoading
          ? _buildLoadingState()
          : _errorMessage != null
          ? _buildErrorState()
          : Column(
        children: [
          _buildHeader(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadCagnottes,
              child: _buildCagnottesList(),
            ),
          ),
        ],
      ),
    );
  }
}

// Classe temporaire pour CagnotteDetailScreen (à créer après)
class CagnotteDetailScreen extends StatelessWidget {
  final Cagnotte cagnotte;

  const CagnotteDetailScreen({super.key, required this.cagnotte});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(cagnotte.nom),
      ),
      body: Center(
        child: Text('Détails de ${cagnotte.nom}'),
      ),
    );
  }
}