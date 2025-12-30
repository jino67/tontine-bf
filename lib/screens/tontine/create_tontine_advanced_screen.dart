import 'package:flutter/material.dart';
import 'package:app_tontine_bf/models/tontine.dart';
import 'package:app_tontine_bf/services/tontine_service.dart';
import 'package:app_tontine_bf/services/auth_service.dart';
import 'package:app_tontine_bf/config/theme.dart';

class CreateTontineAdvancedScreen extends StatefulWidget {
  const CreateTontineAdvancedScreen({super.key});

  @override
  State<CreateTontineAdvancedScreen> createState() => _CreateTontineAdvancedScreenState();
}

class _CreateTontineAdvancedScreenState extends State<CreateTontineAdvancedScreen> {
  final _formKey = GlobalKey<FormState>();
  final AuthService _authService = AuthService();
  final TontineService _tontineService = TontineService();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _durationController = TextEditingController();
  final TextEditingController _participantsController = TextEditingController();
  final TextEditingController _objectiveController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _searchResults = [];
  List<Map<String, dynamic>> _selectedUsers = [];
  bool _isSearching = false;

  // Types de tontines disponibles
  final List<Map<String, dynamic>> _tontineTypes = [
    {
      'type': TypeTontine.tirageAuSort,
      'name': 'Tirage au Sort',
      'description': 'Plusieurs gagnants tirés au hasard chaque cycle',
      'icon': Icons.shuffle,
      'maxParticipants': 20,
    },
    {
      'type': TypeTontine.tourDeRole,
      'name': 'Tour de Rôle',
      'description': 'Chaque membre reçoit à son tour selon un ordre défini',
      'icon': Icons.rotate_right,
      'maxParticipants': 15,
    },
    {
      'type': TypeTontine.cagnotteSolidaire,
      'name': 'Cagnotte Solidaire',
      'description': 'Collecte pour une personne ou une cause spécifique',
      'icon': Icons.volunteer_activism,
      'maxParticipants': 50,
    },
    {
      'type': TypeTontine.epargnePersonnelle,
      'name': 'Épargne Personnelle',
      'description': 'Épargnez seul pour atteindre vos objectifs',
      'icon': Icons.savings,
      'maxParticipants': 1,
    },
    {
      'type': TypeTontine.epargneGroupe,
      'name': 'Épargne de Groupe',
      'description': 'Épargnez ensemble pour un projet commun',
      'icon': Icons.group,
      'maxParticipants': 10,
    },
  ];

  TypeTontine? _selectedType;
  Frequency? _selectedFrequency;
  bool _isLoading = false;

  Future<void> _searchUsers() async {
    if (_searchController.text.isEmpty) return;

    setState(() => _isSearching = true);

    try {
      final results = await _tontineService.searchUsers(_searchController.text);
      if (!mounted) return;

      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSearching = false);
      // print('Search error: $e');
    }
  }

  void _selectUser(Map<String, dynamic> user) {
    if (!_selectedUsers.any((u) => u['id'] == user['id'])) {
      setState(() {
        _selectedUsers.add(user);
        _searchController.clear();
        _searchResults.clear();
      });
    }
  }

  void _removeUser(Map<String, dynamic> user) {
    setState(() {
      _selectedUsers.removeWhere((u) => u['id'] == user['id']);
    });
  }

  Future<void> _createTontine() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedType == null || _selectedFrequency == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez sélectionner le type et la fréquence'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    // DÉBUT DE LA CORRECTION CRITIQUE (Garantir que creatorId est un int valide)
    final String? creatorIdString = await _authService.getUserId();

    // Tente de parser la chaîne en int. Renvoie null si la chaîne est vide ou non-numérique.
    final int? creatorId = (creatorIdString != null && creatorIdString.isNotEmpty)
        ? int.tryParse(creatorIdString)
        : null;

    if (creatorId == null || creatorId <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erreur critique: ID utilisateur non trouvé ou invalide. Veuillez vous reconnecter.'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() => _isLoading = false);
      return;
    }
    // FIN DE LA CORRECTION CRITIQUE

    try {
      final maxParticipants = _selectedType == TypeTontine.epargnePersonnelle
          ? 1
          : int.tryParse(_participantsController.text) ?? 1;

      // <-- ✅ MODIFICATION : Extraire les IDs des utilisateurs sélectionnés
      final List<int> invitedUserIds = _selectedUsers.map((user) {
        // .toString() est plus sûr au cas où l'ID viendrait du JSON en tant que String
        return int.parse(user['id'].toString());
      }).toList();


      final result = await _tontineService.createTontine(
        creatorId: creatorId, // Utilise le ID déjà vérifié
        nom: _nameController.text,
        type: _selectedType!,
        montant: double.parse(_amountController.text),
        frequence: _selectedFrequency!,
        duree: int.parse(_durationController.text),
        maxParticipants: maxParticipants,
        objectif: _objectiveController.text.isEmpty ? null : _objectiveController.text,
        invitedUserIds: invitedUserIds, // <-- ✅ MODIFICATION : On passe la liste d'IDs
      );

      if (!mounted) return;

      if (result['success'] == true) {
        // 1. Affiche le message de succès
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Tontine créée! Code: ${result['code_invitation']}'),
            backgroundColor: tontineAccentDark,
          ),
        );

        // 2. Ferme l'écran et renvoie 'true' pour rafraîchir la liste parente.
        Navigator.pop(context, true);

      } else {
        // Gestion d'erreur si l'API retourne success: false
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Échec de la création: ${result['message']}"),
            backgroundColor: Colors.red,
          ),
        );
      }


    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de la création de la tontine: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildTypeSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Type de Tontine *',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _tontineTypes.map((type) {
            final isSelected = _selectedType == type['type'];
            return GestureDetector(
              onTap: () {
                setState(() {
                  _selectedType = type['type'] as TypeTontine;
                  if (type['type'] == TypeTontine.epargnePersonnelle) {
                    _participantsController.text = '1';
                  } else if (_participantsController.text == '1') {
                    // EFFACE '1' SI ON PASSE D'ÉPARGNE PERSO À UN TYPE DE GROUPE
                    _participantsController.clear();
                  }
                });
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isSelected ? tontinePrimaryColor.withOpacity(0.1) : tontineWhite,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? tontinePrimaryColor : Colors.grey.shade300,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      type['icon'] as IconData,
                      color: isSelected ? tontinePrimaryColor : tontineTextLight,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      type['name'] as String,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: isSelected ? tontinePrimaryColor : tontineTextColor,
                      ),
                    ),
                    SizedBox(
                      width: 120,
                      child: Text(
                        type['description'] as String,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 10,
                          color: isSelected ? tontinePrimaryColor : tontineTextLight,
                        ),
                        maxLines: 2,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildFrequencySelection() {
    final List<Map<String, dynamic>> frequencies = [
      {'value': Frequency.quotidien, 'label': 'Quotidien'},
      {'value': Frequency.hebdomadaire, 'label': 'Hebdomadaire'},
      {'value': Frequency.mensuel, 'label': 'Mensuel'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Fréquence *',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: frequencies.map((freq) {
            final isSelected = _selectedFrequency == freq['value'];
            return ChoiceChip(
              label: Text(freq['label'] as String),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  _selectedFrequency = selected ? freq['value'] as Frequency : null;
                });
              },
              selectedColor: tontinePrimaryColor.withOpacity(0.2),
              labelStyle: TextStyle(
                color: isSelected ? tontinePrimaryColor : tontineTextColor,
                fontWeight: FontWeight.w600,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildUserSearch() {
    // Masquer la recherche si c'est une épargne personnelle
    if (_selectedType == TypeTontine.epargnePersonnelle) return Container();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Inviter des membres',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Rechercher par numéro...',
                  suffixIcon: _isSearching
                      ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : IconButton(
                    icon: const Icon(Icons.search),
                    onPressed: _searchUsers,
                  ),
                ),
                onChanged: (value) => _searchUsers(),
              ),
            ),
          ],
        ),
        if (_searchResults.isNotEmpty) ...[
          const SizedBox(height: 8),
          ..._searchResults.map((user) => ListTile(
            leading: CircleAvatar(
              backgroundColor: tontinePrimaryColor.withOpacity(0.1),
              child: Text(
                (user['full_name'] as String)[0],
                style: const TextStyle(
                  color: tontinePrimaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(user['full_name'] as String),
            subtitle: Text(user['phone_number'] as String),
            trailing: IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => _selectUser(user),
            ),
          )),
        ],
        if (_selectedUsers.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text('Membres invités:'),
          Wrap(
            spacing: 8,
            children: _selectedUsers.map((user) => Chip(
              label: Text(user['full_name'] as String),
              onDeleted: () => _removeUser(user),
            )).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildFormField({
    required String label,
    required IconData icon,
    required TextEditingController controller,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    bool enabled = true, // Paramètre activé
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: tontineTextColor,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          enabled: enabled, // Utilisation du paramètre enabled
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: tontinePrimaryColor),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            filled: true,
            fillColor: enabled ? tontineWhite : tontineBackgroundColor, // Couleur de fond si désactivé
          ),
          validator: validator,
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Détermine si le type sélectionné est l'épargne personnelle
    final isPersonalSavings = _selectedType == TypeTontine.epargnePersonnelle;

    return Scaffold(
      backgroundColor: tontineBackgroundColor,
      appBar: AppBar(
        title: const Text('Nouvelle Tontine'),
        backgroundColor: tontinePrimaryColor,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: tontineWhite),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(tontinePrimaryColor),
        ),
      )
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // En-tête
              Center(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: tontinePrimaryColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.group_add,
                    size: 40,
                    color: tontinePrimaryColor,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Center(
                child: Text(
                  'Créez votre Tontine',
                  style: AppTextStyles.titleMedium.copyWith(
                    color: tontinePrimaryColor,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Center(
                child: Text(
                  'Personnalisez votre tontine selon vos besoins',
                  style: AppTextStyles.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 30),

              // Type de tontine
              _buildTypeSelection(),
              const SizedBox(height: 20),

              // Fréquence
              _buildFrequencySelection(),
              const SizedBox(height: 20),

              // Nom de la tontine
              _buildFormField(
                label: 'Nom de la Tontine *',
                icon: Icons.title,
                controller: _nameController,
                validator: (value) => value!.isEmpty ? 'Le nom est requis' : null,
              ),

              // Montant
              _buildFormField(
                label: 'Montant par cycle (FCFA) *',
                icon: Icons.money,
                controller: _amountController,
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value!.isEmpty) return 'Le montant est requis';
                  final amount = double.tryParse(value);
                  if (amount == null || amount <= 0) return 'Montant invalide';
                  return null;
                },
              ),

              // Participants (Adaptation en fonction du type)
              _buildFormField(
                // Mise à jour du label pour refléter la valeur fixe
                label: 'Nombre maximum de participants ${isPersonalSavings ? '(Fixé à 1)' : '*'}',
                icon: Icons.people,
                controller: _participantsController,
                keyboardType: TextInputType.number,
                // Désactive le champ si c'est une épargne personnelle
                enabled: !isPersonalSavings,
                validator: (value) {
                  // Pas de validation si le champ est désactivé
                  if (isPersonalSavings) return null;
                  if (value!.isEmpty) return 'Le nombre de participants est requis';
                  final max = int.tryParse(value);
                  if (max == null || max < 1) return 'Minimum 1 participant (vous)';
                  return null;
                },
              ),

              // Durée
              _buildFormField(
                label: 'Durée (nombre de cycles) *',
                icon: Icons.calendar_today,
                controller: _durationController,
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value!.isEmpty) return 'La durée est requise';
                  final duration = int.tryParse(value);
                  if (duration == null || duration <= 0) return 'Durée invalide';
                  return null;
                },
              ),

              // Objectif
              _buildFormField(
                label: 'Objectif (optionnel)',
                icon: Icons.flag,
                controller: _objectiveController,
              ),

              // Recherche d'utilisateurs (S'adapte via la condition interne à _buildUserSearch)
              _buildUserSearch(),

              const SizedBox(height: 30),

              // Bouton de création
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _createTontine,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: tontinePrimaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(tontineWhite),
                    ),
                  )
                      : const Text(
                    'Créer la Tontine',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: tontineWhite,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _durationController.dispose();
    _participantsController.dispose();
    _objectiveController.dispose();
    _searchController.dispose();
    super.dispose();
  }
}