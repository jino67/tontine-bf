import 'package:flutter/material.dart';
import 'package:app_tontine_bf/config/theme.dart';
import 'package:app_tontine_bf/services/auth_service.dart';
import 'package:app_tontine_bf/features/cagnotte/services/cagnotte_service.dart';
import 'package:app_tontine_bf/features/cagnotte/models/cagnotte_model.dart';
import 'package:app_tontine_bf/features/cagnotte/widgets/montant_selector.dart';

class ParticipationScreen extends StatefulWidget {
  final Cagnotte cagnotte;

  const ParticipationScreen({super.key, required this.cagnotte});

  @override
  State<ParticipationScreen> createState() => _ParticipationScreenState();
}

class _ParticipationScreenState extends State<ParticipationScreen> {
  final CagnotteService _cagnotteService = CagnotteService();
  final AuthService _authService = AuthService();

  double _selectedMontant = 0;
  bool _isSubmitting = false;
  String? _errorMessage;
  String? _userId;

  @override
  void initState() {
    super.initState();
    // Sélectionner le montant minimum par défaut
    _selectedMontant = widget.cagnotte.montantMin;
    _getUserId();
  }

  Future<void> _getUserId() async {
    final userId = await _authService.getUserId();
    setState(() {
      _userId = userId;
    });
  }

  Future<void> _participer() async {
    if (_userId == null) {
      setState(() {
        _errorMessage = 'Utilisateur non connecté';
      });
      return;
    }

    if (_selectedMontant < widget.cagnotte.montantMin) {
      setState(() {
        _errorMessage = 'Montant inférieur au minimum requis: ${widget.cagnotte.montantMin} FCFA';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final result = await _cagnotteService.participerCagnotte(
        userId: _userId!,
        cagnotteId: widget.cagnotte.id,
        montant: _selectedMontant,
      );

      if (result['success'] == true) {
        // Succès
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Participation enregistrée !'),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.pop(context, true); // Retour avec succès
      } else {
        // Erreur
        setState(() {
          _errorMessage = result['message'] ?? 'Erreur lors de la participation';
          _isSubmitting = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Erreur: $e';
        _isSubmitting = false;
      });
    }
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
            'Participer à',
            style: TextStyle(
              fontSize: 18,
              color: tontineWhite.withOpacity(0.9),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.cagnotte.nom,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: tontineWhite,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: tontineWhite.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              widget.cagnotte.typeString,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: tontineWhite,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMontantSection() {
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
            '💰 Choisissez votre montant',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: tontineTextColor,
            ),
          ),
          const SizedBox(height: 16),

          // Sélecteur de montant
          MontantSelector(
            montants: widget.cagnotte.montantsAutorises,
            montantMin: widget.cagnotte.montantMin,
            accepteMontantsLibres: widget.cagnotte.accepteMontantsLibres,
            selectedMontant: _selectedMontant,
            onMontantChanged: (montant) {
              setState(() {
                _selectedMontant = montant;
                _errorMessage = null;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsSection() {
    final tickets = (_selectedMontant / 250).floor();

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
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Montant sélectionné',
                style: TextStyle(
                  fontSize: 16,
                  color: tontineTextLight,
                ),
              ),
              Text(
                '${_selectedMontant.toStringAsFixed(0)} FCFA',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: tontineTextColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Tickets gagnés',
                style: TextStyle(
                  fontSize: 16,
                  color: tontineTextLight,
                ),
              ),
              Row(
                children: [
                  Icon(
                    Icons.confirmation_number,
                    size: 20,
                    color: tontinePrimaryColor,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$tickets ticket${tickets > 1 ? 's' : ''}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: tontinePrimaryColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (tickets > 0)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Chances approximatives',
                  style: TextStyle(
                    fontSize: 16,
                    color: tontineTextLight,
                  ),
                ),
                Text(
                  '${_calculateChances(tickets)}%',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: tontineAccentColor,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildActionButton() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          if (_errorMessage != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline,
                    color: Colors.red,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _participer,
              style: ElevatedButton.styleFrom(
                backgroundColor: tontinePrimaryColor,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
                  : Text(
                'CONFIRMER LA PARTICIPATION',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: tontineWhite,
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),
          TextButton(
            onPressed: _isSubmitting ? null : () => Navigator.pop(context),
            child: Text(
              'Annuler',
              style: TextStyle(
                color: tontineTextLight,
              ),
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
        title: const Text('Participation'),
        backgroundColor: tontinePrimaryColor,
      ),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: ListView(
              children: [
                _buildMontantSection(),
                _buildDetailsSection(),
                _buildActionButton(),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // === FONCTION UTILITAIRE ===

  double _calculateChances(int tickets) {
    // Calcul simplifié - en réalité ça dépend du total des tickets
    // Pour l'instant on fait une estimation basée sur le nombre de participants
    final participants = widget.cagnotte.participantsCount;
    if (participants == 0) return 100.0;

    final chanceEstimee = (tickets / (participants * 2)) * 100;
    return chanceEstimee.clamp(0.1, 100.0);
  }
}