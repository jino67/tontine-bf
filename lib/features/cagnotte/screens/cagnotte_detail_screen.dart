import 'package:flutter/material.dart';
import 'package:app_tontine_bf/config/theme.dart';
import 'package:app_tontine_bf/services/auth_service.dart';
import 'package:app_tontine_bf/features/cagnotte/services/cagnotte_service.dart';
import 'package:app_tontine_bf/features/cagnotte/models/cagnotte_model.dart';
import 'package:app_tontine_bf/features/cagnotte/screens/participation_screen.dart';
import 'package:app_tontine_bf/features/cagnotte/widgets/montant_selector.dart';

class CagnotteDetailScreen extends StatefulWidget {
  final Cagnotte cagnotte;

  const CagnotteDetailScreen({super.key, required this.cagnotte});

  @override
  State<CagnotteDetailScreen> createState() => _CagnotteDetailScreenState();
}

class _CagnotteDetailScreenState extends State<CagnotteDetailScreen> {
  final CagnotteService _cagnotteService = CagnotteService();
  final AuthService _authService = AuthService();

  late Cagnotte _cagnotte;
  bool _isLoading = true;
  String? _errorMessage;
  String? _userId;

  @override
  void initState() {
    super.initState();
    _cagnotte = widget.cagnotte;
    _loadCagnotteDetail();
  }

  Future<void> _loadCagnotteDetail() async {
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
      final cagnotteDetail = await _cagnotteService.getCagnotteDetail(userId, _cagnotte.id);

      setState(() {
        _cagnotte = cagnotteDetail;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Erreur de chargement: $e';
        _isLoading = false;
      });
    }
  }

  void _navigateToParticipation() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ParticipationScreen(cagnotte: _cagnotte),
      ),
    ).then((_) => _loadCagnotteDetail()); // Recharger après participation
  }

  void _navigateToResultats() {
    // À implémenter plus tard
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Résultats pour ${_cagnotte.nom}'),
        backgroundColor: tontinePrimaryColor,
      ),
    );
  }

  void _navigateToGroupe() {
    // À implémenter plus tard
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Groupe de discussion ${_cagnotte.nom}'),
        backgroundColor: tontinePrimaryColor,
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
            _cagnotte.nom,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: tontineWhite,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: tontineWhite.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _cagnotte.typeString,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: tontineWhite,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _cagnotte.estTerminee
                      ? Colors.red.withOpacity(0.2)
                      : Colors.green.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _cagnotte.statusString,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _cagnotte.estTerminee ? Colors.red : Colors.green,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSection() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tontineWhite,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Montant total
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Cagnotte totale',
                style: TextStyle(
                  fontSize: 16,
                  color: tontineTextLight,
                ),
              ),
              Text(
                '${_cagnotte.montantTotal.toStringAsFixed(0)} FCFA',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: tontineTextColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Participants
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Participants',
                style: TextStyle(
                  fontSize: 16,
                  color: tontineTextLight,
                ),
              ),
              Text(
                '${_cagnotte.participantsCount} personnes',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: tontineTextColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Temps restant
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Temps restant',
                style: TextStyle(
                  fontSize: 16,
                  color: tontineTextLight,
                ),
              ),
              Row(
                children: [
                  Icon(
                    Icons.access_time,
                    size: 16,
                    color: _cagnotte.tempsRestant < 3600 ? Colors.orange : tontinePrimaryColor,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _cagnotte.tempsRestantFormate,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: _cagnotte.tempsRestant < 3600 ? Colors.orange : tontinePrimaryColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGainsSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tontineWhite,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '🎯 Gains potentiels',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: tontineTextColor,
            ),
          ),
          const SizedBox(height: 12),

          // Liste des gains
          Column(
            children: _cagnotte.gainsPotentiels.entries.map((entry) {
              final rang = int.parse(entry.key);
              final gain = entry.value;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: _getRangColor(rang),
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            rang.toString(),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: tontineWhite,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _getRangString(rang),
                          style: TextStyle(
                            fontSize: 14,
                            color: tontineTextColor,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '${gain.toStringAsFixed(0)} FCFA',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: tontinePrimaryColor,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildParticipationSection() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tontineWhite,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '💰 Participation',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: tontineTextColor,
            ),
          ),
          const SizedBox(height: 12),

          if (_cagnotte.dejaParticipe)
            Column(
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Vous participez déjà à cette cagnotte',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.green,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Bonne chance pour le tirage ! 🍀',
                  style: TextStyle(
                    fontSize: 14,
                    color: tontineTextLight,
                  ),
                ),
              ],
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Montants disponibles:',
                  style: TextStyle(
                    fontSize: 14,
                    color: tontineTextLight,
                  ),
                ),
                const SizedBox(height: 8),

                // Affichage des montants disponibles
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _cagnotte.montantsAutorises.map((montant) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: tontinePrimaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$montant FCFA',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: tontinePrimaryColor,
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                if (_cagnotte.accepteMontantsLibres)
                  Text(
                    '✓ Montants libres acceptés (min ${_cagnotte.montantMin} FCFA)',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.green,
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Bouton principal
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _cagnotte.estTerminee || _cagnotte.dejaParticipe ? null : _navigateToParticipation,
              style: ElevatedButton.styleFrom(
                backgroundColor: _cagnotte.estTerminee
                    ? Colors.grey
                    : _cagnotte.dejaParticipe
                    ? tontinePrimaryColor.withOpacity(0.5)
                    : tontinePrimaryColor,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                _cagnotte.estTerminee
                    ? 'Cagnotte terminée'
                    : _cagnotte.dejaParticipe
                    ? 'Déjà participé'
                    : 'PARTICIPER MAINTENANT',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: tontineWhite,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Boutons secondaires
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _cagnotte.estTerminee ? _navigateToResultats : null,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    side: BorderSide(
                      color: _cagnotte.estTerminee ? tontinePrimaryColor : Colors.grey,
                    ),
                  ),
                  child: Text(
                    'Voir résultats',
                    style: TextStyle(
                      color: _cagnotte.estTerminee ? tontinePrimaryColor : Colors.grey,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: _navigateToGroupe,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    side: const BorderSide(color: tontinePrimaryColor),
                  ),
                  child: Text(
                    'Groupe discussion',
                    style: TextStyle(
                      color: tontinePrimaryColor,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
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
            'Chargement des détails...',
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
            onPressed: _loadCagnotteDetail,
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
        title: Text(_cagnotte.nom),
        backgroundColor: tontinePrimaryColor,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadCagnotteDetail,
            tooltip: 'Actualiser',
          ),
        ],
      ),
      body: _isLoading
          ? _buildLoadingState()
          : _errorMessage != null
          ? _buildErrorState()
          : RefreshIndicator(
        onRefresh: _loadCagnotteDetail,
        child: ListView(
          children: [
            _buildHeader(),
            _buildStatsSection(),
            _buildGainsSection(),
            _buildParticipationSection(),
            _buildActionButtons(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // === FONCTIONS UTILITAIRES ===

  Color _getRangColor(int rang) {
    switch (rang) {
      case 1: return const Color(0xFFFFD700); // Or
      case 2: return const Color(0xFFC0C0C0); // Argent
      case 3: return const Color(0xFFCD7F32); // Bronze
      default: return tontinePrimaryColor;
    }
  }

  String _getRangString(int rang) {
    switch (rang) {
      case 1: return '1er prix';
      case 2: return '2ème prix';
      case 3: return '3ème prix';
      default: return '$rangème prix';
    }
  }
}