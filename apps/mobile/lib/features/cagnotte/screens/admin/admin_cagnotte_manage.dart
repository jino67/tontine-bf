import 'package:flutter/material.dart';
import 'package:app_tontine_bf/config/theme.dart';
import 'package:app_tontine_bf/features/cagnotte/models/cagnotte_model.dart';
import 'admin_tirage_config.dart'; // Ajouter cet import

class AdminCagnotteManage extends StatefulWidget {
  const AdminCagnotteManage({super.key});

  @override
  State<AdminCagnotteManage> createState() => _AdminCagnotteManageState();
}

class _AdminCagnotteManageState extends State<AdminCagnotteManage> {
  List<Cagnotte> _cagnottes = []; // Retirer 'final' pour pouvoir modifier
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCagnottes();
  }

  Future<void> _loadCagnottes() async {
    // Simulation de chargement
    await Future.delayed(const Duration(seconds: 1));

    // Données simulées
    final cagnottes = [
      Cagnotte(
        id: 1,
        nom: 'Cagnotte Flash Quotidienne',
        type: CagnotteType.flash24h,
        montantTotal: 35000,
        montantMin: 250,
        montantsAutorises: [250, 500, 1000, 2000, 5000, 10000],
        accepteMontantsLibres: true,
        nombreGagnants: 5,
        dateDebut: DateTime.now().subtract(const Duration(hours: 12)),
        dateFin: DateTime.now().add(const Duration(hours: 12)),
        status: CagnotteStatus.active,
        participantsCount: 45,
      ),
      Cagnotte(
        id: 2,
        nom: 'Cagnotte Hebdomadaire Premium',
        type: CagnotteType.hebdo7j,
        montantTotal: 120000,
        montantMin: 1000,
        montantsAutorises: [1000, 2000, 5000, 10000],
        accepteMontantsLibres: false,
        nombreGagnants: 3,
        dateDebut: DateTime.now().subtract(const Duration(days: 2)),
        dateFin: DateTime.now().add(const Duration(days: 5)),
        status: CagnotteStatus.active,
        participantsCount: 28,
      ),
      Cagnotte(
        id: 3,
        nom: 'Cagnotte Mensuelle Familiale',
        type: CagnotteType.mensuelle30j,
        montantTotal: 0,
        montantMin: 500,
        montantsAutorises: [500, 1000, 2000, 5000],
        accepteMontantsLibres: true,
        nombreGagnants: 10,
        dateDebut: DateTime.now().add(const Duration(days: 1)),
        dateFin: DateTime.now().add(const Duration(days: 31)),
        status: CagnotteStatus.enCours,
        participantsCount: 0,
      ),
    ];

    setState(() {
      _cagnottes = cagnottes; // Maintenant ça fonctionne car _cagnottes n'est plus final
      _isLoading = false;
    });
  }

  void _createNewCagnotte() {
    // À implémenter - navigation vers écran création
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Création d\'une nouvelle cagnotte'),
        backgroundColor: tontinePrimaryColor,
      ),
    );
  }

  void _editCagnotte(Cagnotte cagnotte) {
    // À implémenter - navigation vers écran édition
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Édition de ${cagnotte.nom}'),
        backgroundColor: tontinePrimaryColor,
      ),
    );
  }

  void _executerTirage(Cagnotte cagnotte) {
    // À implémenter - appel API tirage
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Tirage pour ${cagnotte.nom}'),
        backgroundColor: Colors.green,
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
            'Gestion des Cagnottes',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: tontineWhite,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Administration du système de cagnottes',
            style: TextStyle(
              fontSize: 16,
              color: tontineWhite.withOpacity(0.9),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildAdminStat('${_cagnottes.length}', 'Cagnottes', tontineWhite),
              const SizedBox(width: 20),
              _buildAdminStat(
                  '${_cagnottes.where((c) => c.status == CagnotteStatus.active).length}',
                  'Actives',
                  tontineAccentColor
              ),
              const SizedBox(width: 20),
              _buildAdminStat(
                  '${_cagnottes.where((c) => c.status == CagnotteStatus.terminee).length}',
                  'Terminées',
                  tontineGold
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAdminStat(String value, String label, Color color) {
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

  Widget _buildCagnotteCard(Cagnotte cagnotte) {
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
            // En-tête avec nom et statut
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    cagnotte.nom,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(cagnotte.status),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    cagnotte.statusString,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: tontineWhite,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Type et dates
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: tontinePrimaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    cagnotte.typeString,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: tontinePrimaryColor,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.people_outline,
                  size: 14,
                  color: tontineTextLight,
                ),
                const SizedBox(width: 4),
                Text(
                  '${cagnotte.participantsCount} participants',
                  style: TextStyle(
                    fontSize: 12,
                    color: tontineTextLight,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Statistiques
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${cagnotte.montantTotal.toStringAsFixed(0)} FCFA',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Cagnotte totale',
                      style: TextStyle(
                        fontSize: 12,
                        color: tontineTextLight,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${cagnotte.nombreGagnants} gagnants',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: tontinePrimaryColor,
                      ),
                    ),
                    Text(
                      'Tirage prévu',
                      style: TextStyle(
                        fontSize: 12,
                        color: tontineTextLight,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Boutons d'action admin
            // MODIFICATION DANS _buildCagnotteCard - Section boutons d'action admin
// Remplacer la section des boutons par ceci :

// Boutons d'action admin
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _editCagnotte(cagnotte),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: tontinePrimaryColor),
                    ),
                    child: Text(
                      'Modifier',
                      style: TextStyle(color: tontinePrimaryColor),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // NOUVEAU BOUTON CONFIG TIRAGE HYBRIDE
                IconButton(
                  icon: Icon(Icons.shuffle, size: 20),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AdminTirageConfigScreen(cagnotte: cagnotte),
                      ),
                    );
                  },
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.blue.withOpacity(0.1),
                  ),
                  tooltip: 'Configurer tirage hybride',
                ),
                const SizedBox(width: 8),
                if (cagnotte.status == CagnotteStatus.active)
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _executerTirage(cagnotte),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                      ),
                      child: const Text(
                        'Lancer tirage',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
              ],
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
            'Chargement des cagnottes...',
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
        title: const Text('Admin Cagnottes'),
        backgroundColor: tontinePrimaryColor,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _createNewCagnotte,
            tooltip: 'Nouvelle cagnotte',
          ),
        ],
      ),
      body: _isLoading
          ? _buildLoadingState()
          : Column(
        children: [
          _buildHeader(),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: ListView.builder(
                itemCount: _cagnottes.length,
                itemBuilder: (context, index) {
                  return _buildCagnotteCard(_cagnottes[index]);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(CagnotteStatus status) {
    switch (status) {
      case CagnotteStatus.active: return Colors.green;
      case CagnotteStatus.terminee: return Colors.grey;
      case CagnotteStatus.enCours: return Colors.orange;
    }
  }
}