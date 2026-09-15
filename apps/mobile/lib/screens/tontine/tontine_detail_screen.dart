import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:app_tontine_bf/models/tontine.dart';
import 'package:app_tontine_bf/services/tontine_service.dart';
import 'package:app_tontine_bf/config/theme.dart';

class TontineDetailScreen extends StatefulWidget {
  final Tontine tontine;

  const TontineDetailScreen({super.key, required this.tontine});

  @override
  State<TontineDetailScreen> createState() => _TontineDetailScreenState();
}

class _TontineDetailScreenState extends State<TontineDetailScreen> {
  final TontineService _tontineService = TontineService();
  List<Map<String, dynamic>> _participants = [];
  bool _isLoading = true;
  bool _isSharing = false;

  @override
  void initState() {
    super.initState();
    _loadParticipants();
  }

  Future<void> _loadParticipants() async {
    try {
      // Assurez-vous d'utiliser la propriété id de la Tontine
      final participants = await _tontineService.getTontineParticipants(widget.tontine.id);
      if (mounted) {
        setState(() {
          _participants = participants;
          _isLoading = false;
        });
      }
    } catch (e) {
      // print('Error loading participants: $e'); // Supprimé: avoid_print
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _shareTontine() async {
    if (!mounted) return;
    setState(() => _isSharing = true);

    try {
      final result = await _tontineService.generateInvitationCode(widget.tontine.id);

      if (result['success'] == true) {
        final invitationCode = result['code_invitation'];
        final message = "Rejoignez ma tontine '${widget.tontine.nom}' sur Tontine BF!\n"
            "Code d'invitation: $invitationCode\n"
            "Montant: ${widget.tontine.montantCotisation} FCFA ${widget.tontine.frequencyString}\n"
            "Type: ${widget.tontine.typeString}";

        // Encodage URI pour le lien WhatsApp
        final Uri url = Uri.parse("https://wa.me/?text=${Uri.encodeComponent(message)}");

        // Utilisation de launchUrl simple, la gestion de l'échec est intégrée
        final success = await launchUrl(url, mode: LaunchMode.externalApplication);

        if (!success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Impossible de lancer l'application (WhatsApp non installé ?)"),
              backgroundColor: Colors.red, // Utilisation d'une couleur d'erreur standard
            ),
          );
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Échec de la génération du code : ${result['message']}"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Erreur de partage inattendue: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSharing = false);
      }
    }
  }

  Widget _buildParticipantCard(Map<String, dynamic> participant) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: tontinePrimaryColor.withOpacity(0.1),
          child: Text(
            (participant['full_name'] as String?)?.isNotEmpty == true
                ? participant['full_name'][0].toUpperCase()
                : '?', // Gestion des noms vides ou null
            style: const TextStyle(
              color: tontinePrimaryColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          participant['full_name'] ?? 'Utilisateur inconnu',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(participant['phone_number'] ?? 'N° non disponible'),
        trailing: (participant['is_creator'] == true || participant['is_creator'] == 1)
            ? Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: tontineAccentColor.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            'Créateur',
            style: TextStyle(
              fontSize: 12,
              color: tontineAccentDark,
              fontWeight: FontWeight.w600,
            ),
          ),
        )
            : null,
      ),
    );
  }

  Widget _buildInfoSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.tontine.nom,
                  style: AppTextStyles.titleMedium,
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: widget.tontine.status == TontineStatus.active
                        ? tontineAccentColor.withOpacity(0.2)
                        : tontinePrimaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    widget.tontine.statusString,
                    style: TextStyle(
                      color: widget.tontine.status == TontineStatus.active
                          ? tontineAccentDark
                          : tontinePrimaryColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),
            _buildInfoRow('Type', widget.tontine.typeString),
            _buildInfoRow('Montant', '${widget.tontine.montantCotisation} FCFA'),
            _buildInfoRow('Fréquence', widget.tontine.frequencyString),
            _buildInfoRow('Durée', '${widget.tontine.duree} cycles'),
            if (widget.tontine.maxParticipants > 1)
              _buildInfoRow('Participants', '${_participants.length}/${widget.tontine.maxParticipants}'),
            if (widget.tontine.objectif != null && widget.tontine.objectif!.isNotEmpty)
              _buildInfoRow('Objectif', widget.tontine.objectif!),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppTextStyles.bodyMedium.copyWith(
              color: tontineTextLight,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
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
        title: const Text('Détails de la Tontine'),
        backgroundColor: tontinePrimaryColor,
        actions: [
          IconButton(
            icon: _isSharing
                ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(tontineWhite), // Rendre visible sur l'AppBar
              ),
            )
                : const Icon(Icons.share),
            onPressed: _isSharing ? null : _shareTontine,
            tooltip: 'Partager',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section informations
            _buildInfoSection(),
            const SizedBox(height: 25),

            // Section participants
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Participants (${_participants.length})',
                  style: AppTextStyles.titleMedium,
                ),
                TextButton(
                  onPressed: _shareTontine,
                  child: const Text(
                    'Inviter',
                    style: TextStyle(
                      color: tontinePrimaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),

            // Liste des participants
            if (_participants.isEmpty)
              Center( // Ajout de Center pour aligner le message
                child: Container(
                  padding: const EdgeInsets.all(40),
                  child: Column(
                    children: [
                      Icon(
                        Icons.group_off,
                        size: 60,
                        color: tontineTextLight.withOpacity(0.5),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Aucun participant',
                        style: TextStyle(
                          color: tontineTextLight,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Partagez le lien pour inviter des membres',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: tontineTextLight,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Column(
                children: _participants
                    .map((participant) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _buildParticipantCard(participant),
                ))
                    .toList(),
              ),
          ],
        ),
      ),
    );
  }
}