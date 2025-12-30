import 'package:flutter/material.dart';
import 'package:app_tontine_bf/config/theme.dart';
import 'package:app_tontine_bf/features/cagnotte/models/cagnotte_model.dart';
import 'package:app_tontine_bf/features/cagnotte/models/gagnant_model.dart';

class ResultatsScreen extends StatefulWidget {
  final int cagnotteId;

  const ResultatsScreen({super.key, required this.cagnotteId});

  @override
  State<ResultatsScreen> createState() => _ResultatsScreenState();
}

class _ResultatsScreenState extends State<ResultatsScreen> {
  late Future<Map<String, dynamic>> _resultatsFuture;
  List<Gagnant> _gagnants = [];
  Cagnotte? _cagnotte;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _resultatsFuture = _loadResultats();
  }

  Future<Map<String, dynamic>> _loadResultats() async {
    // Pour l'instant, on simule les données
    // Plus tard, on appellera l'API tirage_api.php
    await Future.delayed(const Duration(seconds: 2));

    // Données simulées
    final cagnotte = Cagnotte(
      id: widget.cagnotteId,
      nom: 'Cagnotte Flash Test',
      type: CagnotteType.flash24h,
      montantTotal: 150000,
      montantMin: 250,
      montantsAutorises: [250, 500, 1000, 2000, 5000, 10000],
      accepteMontantsLibres: true,
      nombreGagnants: 5,
      dateDebut: DateTime.now().subtract(const Duration(days: 1)),
      dateFin: DateTime.now(),
      status: CagnotteStatus.terminee,
    );

    final gagnants = [
      Gagnant(
        id: 1,
        cagnotteId: widget.cagnotteId,
        userId: 101,
        rang: 1,
        gain: 60000,
        modeSelection: ModeSelection.aleatoire,
        messageVictoire: 'Merci à tous ! Je suis super content 🎉',
        dateGain: DateTime.now(),
        userName: 'Jean Koffi',
        userPhone: '70123456',
      ),
      Gagnant(
        id: 2,
        cagnotteId: widget.cagnotteId,
        userId: 102,
        rang: 2,
        gain: 37500,
        modeSelection: ModeSelection.aleatoire,
        messageVictoire: 'Génial ! Merci pour cette opportunité 💰',
        dateGain: DateTime.now(),
        userName: 'Marie Ouédraogo',
        userPhone: '70234567',
      ),
      Gagnant(
        id: 3,
        cagnotteId: widget.cagnotteId,
        userId: 103,
        rang: 3,
        gain: 22500,
        modeSelection: ModeSelection.aleatoire,
        messageVictoire: null, // Pas encore posté de message
        dateGain: DateTime.now(),
        userName: 'Paul Sawadogo',
        userPhone: '70345678',
      ),
    ];

    return {
      'cagnotte': cagnotte,
      'gagnants': gagnants,
      'totalGains': 120000,
    };
  }

  Widget _buildHeader() {
    if (_cagnotte == null) return const SizedBox();

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
            'Résultats du tirage',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: tontineWhite,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _cagnotte!.nom,
            style: TextStyle(
              fontSize: 18,
              color: tontineWhite.withOpacity(0.9),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildStatItem('${_cagnotte!.montantTotal.toStringAsFixed(0)}', 'Cagnotte', tontineWhite),
              const SizedBox(width: 20),
              _buildStatItem('${_gagnants.length}', 'Gagnants', tontineAccentColor),
              const SizedBox(width: 20),
              _buildStatItem('120000', 'Gains', tontineGold),
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
            fontSize: 16,
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

  Widget _buildGagnantsList() {
    if (_gagnants.isEmpty) {
      return const Center(
        child: Text('Aucun gagnant pour le moment'),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _gagnants.length,
      itemBuilder: (context, index) {
        final gagnant = _gagnants[index];
        return _buildGagnantCard(gagnant);
      },
    );
  }

  Widget _buildGagnantCard(Gagnant gagnant) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // En-tête avec rang et gain
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getRangColor(gagnant.rang),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _getRangIcon(gagnant.rang),
                        size: 16,
                        color: tontineWhite,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        gagnant.rangString,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: tontineWhite,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${gagnant.gain.toStringAsFixed(0)} FCFA',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: tontinePrimaryColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Infos du gagnant
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: tontinePrimaryColor.withOpacity(0.1),
                  child: Icon(
                    Icons.person,
                    color: tontinePrimaryColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        gagnant.userName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        gagnant.userPhone,
                        style: TextStyle(
                          fontSize: 14,
                          color: tontineTextLight,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Message de victoire ou invitation
            if (gagnant.messageVictoire != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.celebration,
                      size: 16,
                      color: Colors.green,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        gagnant.messageVictoire!,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.green[800],
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.schedule,
                      size: 16,
                      color: Colors.orange,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'En attente du message de victoire...',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.orange[800],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
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
            'Chargement des résultats...',
            style: TextStyle(
              color: tontineTextLight,
            ),
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
        title: const Text('Résultats'),
        backgroundColor: tontinePrimaryColor,
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _resultatsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildLoadingState();
          }

          if (snapshot.hasError) {
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
                    ),
                  ),
                ],
              ),
            );
          }

          if (snapshot.hasData) {
            final data = snapshot.data!;
            _cagnotte = data['cagnotte'] as Cagnotte;
            _gagnants = data['gagnants'] as List<Gagnant>;
            _isLoading = false;

            return Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: _buildGagnantsList(),
                ),
              ],
            );
          }

          return const SizedBox();
        },
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

  IconData _getRangIcon(int rang) {
    switch (rang) {
      case 1: return Icons.emoji_events;
      case 2: return Icons.workspace_premium;
      case 3: return Icons.military_tech;
      default: return Icons.star;
    }
  }
}