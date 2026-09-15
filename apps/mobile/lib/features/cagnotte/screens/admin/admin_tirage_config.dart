// lib/features/cagnotte/screens/admin/admin_tirage_config.dart
import 'package:flutter/material.dart';
import 'package:app_tontine_bf/config/theme.dart';
import 'package:app_tontine_bf/features/cagnotte/models/cagnotte_model.dart';
import 'package:app_tontine_bf/features/cagnotte/services/tirage_service.dart';

class AdminTirageConfigScreen extends StatefulWidget {
  final Cagnotte cagnotte;

  const AdminTirageConfigScreen({super.key, required this.cagnotte});

  @override
  State<AdminTirageConfigScreen> createState() => _AdminTirageConfigScreenState();
}

class _AdminTirageConfigScreenState extends State<AdminTirageConfigScreen> {
  final TirageService _tirageService = TirageService();
  final TextEditingController _raisonController = TextEditingController();

  bool _selectionAdminActive = false;
  Map<int, int> _rangsAdminSelectionnes = {};

  void _onRangSelectionne(int rang, int userId, String raison) {
    setState(() {
      _rangsAdminSelectionnes[rang] = userId;
    });
    _raisonController.text = raison;
  }

  Future<void> _sauvegarderConfig() async {
    // adminId viendrait de AuthService en pratique
    final adminId = "admin_123";

    final result = await _tirageService.configurerTirageHybride(
      cagnotteId: widget.cagnotte.id,
      selectionAdminActive: _selectionAdminActive,
      rangsAdminSelectionnes: _rangsAdminSelectionnes,
      adminId: adminId,
      raisonInterne: _raisonController.text.isEmpty ? null : _raisonController.text,
    );

    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Configuration hybride sauvegardée')),
      );
    }
  }

  Widget _buildRangControl(int rang) {
    final userId = _rangsAdminSelectionnes[rang];

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          child: Text('$rang'),
          backgroundColor: userId != null ? Colors.green : Colors.grey,
        ),
        title: Text('Rang $rang'),
        subtitle: Text(userId != null
            ? 'User ID: $userId'
            : 'Tirage aléatoire'),
        trailing: IconButton(
          icon: Icon(userId != null ? Icons.edit : Icons.add),
          onPressed: () => _showRangConfigDialog(rang),
        ),
      ),
    );
  }

  void _showRangConfigDialog(int rang) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Configurer le rang $rang'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('User ID (0 pour aléatoire):'),
            TextField(
              decoration: InputDecoration(hintText: 'ID utilisateur'),
              onChanged: (value) {
                final userId = int.tryParse(value) ?? 0;
                if (userId > 0) {
                  _onRangSelectionne(rang, userId, 'Raison interne');
                }
              },
            ),
            SizedBox(height: 10),
            TextField(
              controller: _raisonController,
              decoration: InputDecoration(hintText: 'Raison interne (optionnel)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _sauvegarderConfig();
            },
            child: Text('Sauvegarder'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Config Tirage - ${widget.cagnotte.nom}'),
        actions: [
          IconButton(
            icon: Icon(Icons.play_arrow),
            onPressed: () {
              _tirageService.demarrerTirageHybride(
                cagnotteId: widget.cagnotte.id,
                adminId: "admin_123",
              );
            },
            tooltip: 'Démarrer tirage',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Switch activation système hybride
            SwitchListTile(
              title: Text('Activer sélection admin discrète'),
              subtitle: Text('Permet d\'influencer certains rangs'),
              value: _selectionAdminActive,
              onChanged: (value) => setState(() => _selectionAdminActive = value),
            ),

            if (_selectionAdminActive) ...[
              SizedBox(height: 20),
              Text(
                'Configuration des rangs (${widget.cagnotte.nombreGagnants} gagnants)',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 10),
              Expanded(
                child: ListView.builder(
                  itemCount: widget.cagnotte.nombreGagnants,
                  itemBuilder: (context, index) => _buildRangControl(index + 1),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}