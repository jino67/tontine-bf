import 'package:flutter/material.dart';
import 'package:app_tontine_bf/config/theme.dart';

class SavingsScreen extends StatefulWidget {
  const SavingsScreen({super.key});

  @override
  State<SavingsScreen> createState() => _SavingsScreenState();
}

class _SavingsScreenState extends State<SavingsScreen> {
  final List<Map<String, dynamic>> _savingsGoals = [
    {
      'id': '1',
      'name': 'Nouveau Téléphone',
      'targetAmount': 150000,
      'savedAmount': 75000,
      'deadline': DateTime(2024, 12, 31),
      'frequency': 'Hebdomadaire',
      'weeklyAmount': 5000,
    },
    {
      'id': '2',
      'name': 'Voyage en Famille',
      'targetAmount': 500000,
      'savedAmount': 125000,
      'deadline': DateTime(2024, 8, 15),
      'frequency': 'Mensuelle',
      'monthlyAmount': 25000,
    },
    {
      'id': '3',
      'name': 'Frais de Scolarité',
      'targetAmount': 300000,
      'savedAmount': 180000,
      'deadline': DateTime(2024, 9, 1),
      'frequency': 'Quotidienne',
      'dailyAmount': 1000,
    },
  ];

  Widget _buildSavingsCard(Map<String, dynamic> goal) {
    final progress = goal['savedAmount'] / goal['targetAmount'];
    final daysLeft = goal['deadline'].difference(DateTime.now()).inDays;

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
                Text(
                  goal['name'],
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: tontineAccentColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    goal['frequency'],
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: tontineAccentDark,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Barre de progression
            LinearProgressIndicator(
              value: progress,
              backgroundColor: tontineBackgroundColor,
              valueColor: AlwaysStoppedAnimation<Color>(
                progress >= 1 ? tontineAccentDark : tontinePrimaryColor,
              ),
              borderRadius: BorderRadius.circular(10),
              minHeight: 8,
            ),
            const SizedBox(height: 8),

            // Montants
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${goal['savedAmount']} FCFA',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: tontineTextColor,
                  ),
                ),
                Text(
                  '${goal['targetAmount']} FCFA',
                  style: AppTextStyles.bodyMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Détails
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${(progress * 100).toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: tontinePrimaryColor,
                  ),
                ),
                Text(
                  '$daysLeft jours restants',
                  style: AppTextStyles.bodyMedium,
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Bouton d'action
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  _showAddMoneyDialog(goal);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: tontinePrimaryColor.withOpacity(0.1),
                  foregroundColor: tontinePrimaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Ajouter de l\'argent',
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

  void _showAddMoneyDialog(Map<String, dynamic> goal) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Ajouter à ${goal['name']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Épargne actuelle: ${goal['savedAmount']} FCFA'),
            const SizedBox(height: 16),
            TextFormField(
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Montant à ajouter (FCFA)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              // Ajouter l'argent à l'objectif
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Argent ajouté avec succès !'),
                  backgroundColor: tontineAccentDark,
                ),
              );
            },
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );
  }

  void _showCreateGoalDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nouvel Objectif d\'Épargne'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Nom de l\'objectif',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Montant cible (FCFA)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField(
                decoration: const InputDecoration(
                  labelText: 'Fréquence',
                  border: OutlineInputBorder(),
                ),
                items: ['Quotidienne', 'Hebdomadaire', 'Mensuelle']
                    .map((freq) => DropdownMenuItem(
                  value: freq,
                  child: Text(freq),
                ))
                    .toList(),
                onChanged: (value) {},
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Objectif créé avec succès !'),
                  backgroundColor: tontineAccentDark,
                ),
              );
            },
            child: const Text('Créer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalSaved = _savingsGoals.fold<int>(0, (sum, goal) => sum + (goal['savedAmount'] as int));
    final totalTarget = _savingsGoals.fold<int>(0, (sum, goal) => sum + (goal['targetAmount'] as int));

    return Scaffold(
      backgroundColor: tontineBackgroundColor,
      appBar: AppBar(
        title: const Text('Épargne Personnelle'),
        backgroundColor: tontinePrimaryColor,
      ),
      body: Column(
        children: [
          // Carte de résumé
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [tontineAccentDark, tontineAccentColor],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: AppShadows.cardShadow,
            ),
            child: Column(
              children: [
                Text(
                  'Total Épargné',
                  style: TextStyle(
                    fontSize: 16,
                    color: tontineWhite.withOpacity(0.9),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$totalSaved FCFA',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: tontineWhite,
                  ),
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: totalTarget > 0 ? totalSaved / totalTarget : 0,
                  backgroundColor: tontineWhite.withOpacity(0.3),
                  valueColor: const AlwaysStoppedAnimation<Color>(tontineWhite),
                  borderRadius: BorderRadius.circular(10),
                  minHeight: 6,
                ),
                const SizedBox(height: 8),
                Text(
                  'Sur $totalTarget FCFA d\'objectifs',
                  style: TextStyle(
                    color: tontineWhite.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),

          // Liste des objectifs
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Mes Objectifs',
                  style: AppTextStyles.titleMedium,
                ),
                TextButton(
                  onPressed: _showCreateGoalDialog,
                  child: const Text(
                    'Nouvel Objectif',
                    style: TextStyle(
                      color: tontinePrimaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: _savingsGoals.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _savingsGoals.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildSavingsCard(_savingsGoals[index]),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateGoalDialog,
        backgroundColor: tontinePrimaryColor,
        foregroundColor: tontineWhite,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.savings_outlined,
            size: 80,
            color: tontineTextLight.withOpacity(0.3),
          ),
          const SizedBox(height: 20),
          Text(
            'Aucun objectif d\'épargne',
            style: AppTextStyles.titleMedium.copyWith(
              color: tontineTextLight,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Créez votre premier objectif pour commencer à épargner',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMedium,
          ),
          const SizedBox(height: 25),
          ElevatedButton(
            onPressed: _showCreateGoalDialog,
            style: ElevatedButton.styleFrom(
              backgroundColor: tontinePrimaryColor,
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
            ),
            child: const Text(
              'Créer un objectif',
              style: TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}