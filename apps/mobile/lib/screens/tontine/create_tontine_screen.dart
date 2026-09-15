import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:app_tontine_bf/models/tontine.dart';
import 'package:app_tontine_bf/services/auth_service.dart';
import 'package:app_tontine_bf/services/tontine_service.dart';
import 'package:app_tontine_bf/config/theme.dart';

class CreateTontineScreen extends StatefulWidget {
  const CreateTontineScreen({super.key});

  @override
  State<CreateTontineScreen> createState() => _CreateTontineScreenState();
}

class _CreateTontineScreenState extends State<CreateTontineScreen> {
  final _formKey = GlobalKey<FormState>();
  final AuthService _authService = AuthService();
  final TontineService _tontineService = TontineService();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _durationController = TextEditingController();

  // Types de tontines disponibles
  final List<Map<String, dynamic>> _tontineTypes = [
    {
      'type': TypeTontine.tirageAuSort,
      'name': 'Tirage au Sort',
      'description': 'Plusieurs gagnants tirés au hasard chaque cycle',
      'icon': Icons.shuffle,
    },
    {
      'type': TypeTontine.tourDeRole,
      'name': 'Tour de Rôle',
      'description': 'Chaque membre reçoit à son tour selon un ordre défini',
      'icon': Icons.rotate_right,
    },
    {
      'type': TypeTontine.cagnotteSolidaire,
      'name': 'Cagnotte Solidaire',
      'description': 'Collecte pour une personne ou une cause spécifique',
      'icon': Icons.volunteer_activism,
    },
    {
      'type': TypeTontine.epargnePersonnelle,
      'name': 'Épargne Personnelle',
      'description': 'Épargnez seul pour atteindre vos objectifs',
      'icon': Icons.savings,
    },
  ];

  // Fréquences disponibles
  final List<Map<String, dynamic>> _frequencies = [
    {
      'frequency': Frequency.quotidien,
      'name': 'Quotidienne',
      'description': 'Tous les jours',
    },
    {
      'frequency': Frequency.hebdomadaire,
      'name': 'Hebdomadaire',
      'description': 'Toutes les semaines',
    },
    {
      'frequency': Frequency.mensuel,
      'name': 'Mensuelle',
      'description': 'Tous les mois',
    },
  ];

  TypeTontine? _selectedType;
  Frequency? _selectedFrequency;
  DateTime _startDate = DateTime.now();
  bool _isLoading = false;
  bool _useSystemTemplate = false;

  // Tontines système (configurées par l'admin)
  final List<Map<String, dynamic>> _systemTemplates = [
    {
      'name': 'Épargne Quotidienne',
      'type': TypeTontine.epargnePersonnelle,
      'frequency': Frequency.quotidien,
      'amount': 1000,
      'duration': 30,
      'description': 'Idéal pour une épargne régulière',
    },
    {
      'name': 'Épargne Hebdomadaire',
      'type': TypeTontine.epargnePersonnelle,
      'frequency': Frequency.hebdomadaire,
      'amount': 5000,
      'duration': 12,
      'description': 'Parfait pour les projets à moyen terme',
    },
    {
      'name': 'Épargne Mensuelle',
      'type': TypeTontine.epargnePersonnelle,
      'frequency': Frequency.mensuel,
      'amount': 20000,
      'duration': 6,
      'description': 'Excellent pour les gros projets',
    },
  ];

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: tontinePrimaryColor,
              onPrimary: tontineWhite,
              onSurface: tontineTextColor,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _startDate) {
      setState(() {
        _startDate = picked;
      });
    }
  }

  void _applyTemplate(Map<String, dynamic> template) {
    setState(() {
      _nameController.text = template['name'];
      _selectedType = template['type'];
      _selectedFrequency = template['frequency'];
      _amountController.text = template['amount'].toString();
      _durationController.text = template['duration'].toString();
      _useSystemTemplate = true;
    });
  }

  Future<void> _createTontine() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedType == null || _selectedFrequency == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez sélectionner le type et la fréquence'),
          backgroundColor: tontinePrimaryColor,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    // DÉBUT DE LA CORRECTION CRITIQUE
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
          backgroundColor: tontinePrimaryColor,
        ),
      );
      setState(() => _isLoading = false);
      return;
    }
    // FIN DE LA CORRECTION CRITIQUE

    try {
      final result = await _tontineService.createTontine(
        creatorId: creatorId, // Utilise l'int vérifié
        nom: _nameController.text,
        type: _selectedType!,
        montant: double.parse(_amountController.text),
        frequence: _selectedFrequency!,
        duree: int.parse(_durationController.text),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Tontine créée! Code: ${result['code_invitation']}'),
          backgroundColor: tontineAccentDark,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
        ),
      );

      Navigator.pop(context, result);

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: $e'),
          backgroundColor: tontinePrimaryColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildTemplateCard(Map<String, dynamic> template) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: tontinePrimaryColor.withOpacity(0.1),
        ),
      ),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: tontinePrimaryColor.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.auto_awesome,
            color: tontinePrimaryColor,
            size: 20,
          ),
        ),
        title: Text(
          template['name'],
          style: const TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(template['description']),
            const SizedBox(height: 4),
            Text(
              '${template['amount']} FCFA • ${_getFrequencyName(template['frequency'])} • ${template['duration']} cycles',
              style: AppTextStyles.bodyMedium.copyWith(
                color: tontinePrimaryColor,
              ),
            ),
          ],
        ),
        trailing: IconButton(
          icon: Icon(
            Icons.arrow_forward,
            color: tontinePrimaryColor,
          ),
          onPressed: () => _applyTemplate(template),
        ),
      ),
    );
  }

  String _getFrequencyName(Frequency freq) {
    switch (freq) {
      case Frequency.quotidien: return 'Quotidien';
      case Frequency.hebdomadaire: return 'Hebdomadaire';
      case Frequency.mensuel: return 'Mensuel';
    }
  }

  Widget _buildTypeSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Type de Tontine',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: tontineTextColor,
          ),
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
                  _selectedType = type['type'];
                  _useSystemTemplate = false;
                });
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? tontinePrimaryColor.withOpacity(0.1)
                      : tontineWhite,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? tontinePrimaryColor : Colors.grey.shade300,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      type['icon'],
                      color: isSelected ? tontinePrimaryColor : tontineTextLight,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          type['name'],
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: isSelected ? tontinePrimaryColor : tontineTextColor,
                          ),
                        ),
                        SizedBox(
                          width: 200,
                          child: Text(
                            type['description'],
                            style: TextStyle(
                              fontSize: 12,
                              color: isSelected ? tontinePrimaryColor : tontineTextLight,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildFrequencySelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Fréquence de Paiement',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: tontineTextColor,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _frequencies.map((freq) {
            final isSelected = _selectedFrequency == freq['frequency'];
            return GestureDetector(
              onTap: () {
                setState(() {
                  _selectedFrequency = freq['frequency'];
                  _useSystemTemplate = false;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? tontinePrimaryColor.withOpacity(0.1)
                      : tontineWhite,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? tontinePrimaryColor : Colors.grey.shade300,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      freq['name'],
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: isSelected ? tontinePrimaryColor : tontineTextColor,
                      ),
                    ),
                    Text(
                      freq['description'],
                      style: TextStyle(
                        fontSize: 12,
                        color: isSelected ? tontinePrimaryColor : tontineTextLight,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildFormField({
    required String label,
    required IconData icon,
    required TextEditingController controller,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
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
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: tontinePrimaryColor),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            filled: true,
            fillColor: tontineWhite,
          ),
          validator: validator,
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final String displayedDate = DateFormat('dd/MM/yyyy').format(_startDate);

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
        padding: const EdgeInsets.all(20),
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
                  child: Icon(
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
                  'Choisissez un modèle ou créez une tontine personnalisée',
                  style: AppTextStyles.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 30),

              // Modèles système
              if (!_useSystemTemplate) ...[
                const Text(
                  'Modèles Recommandés',
                  style: AppTextStyles.titleMedium,
                ),
                const SizedBox(height: 15),
                ..._systemTemplates.map(_buildTemplateCard).toList(),
                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 20),
                const Center(
                  child: Text(
                    'OU',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: tontineTextLight,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Formulaire personnalisé
              Text(
                _useSystemTemplate ? 'Modèle Appliqué' : 'Création Personnalisée',
                style: AppTextStyles.titleMedium,
              ),
              const SizedBox(height: 20),

              // Nom de la tontine
              _buildFormField(
                label: 'Nom de la Tontine',
                icon: Icons.group_work,
                controller: _nameController,
                validator: (value) => value!.isEmpty ? 'Veuillez nommer la tontine' : null,
              ),

              // Type de tontine
              _buildTypeSelection(),

              // Fréquence
              _buildFrequencySelection(),

              // Montant
              _buildFormField(
                label: 'Montant par membre (FCFA)',
                icon: Icons.payments,
                controller: _amountController,
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value!.isEmpty) return 'Montant requis';
                  if (double.tryParse(value) == null || double.parse(value) <= 0) {
                    return 'Entrez un montant valide';
                  }
                  return null;
                },
              ),

              // Durée
              _buildFormField(
                label: 'Durée (nombre de cycles)',
                icon: Icons.schedule,
                controller: _durationController,
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value!.isEmpty) return 'Durée requise';
                  if (int.tryParse(value) == null || int.parse(value) <= 0) {
                    return 'Entrez une durée valide';
                  }
                  return null;
                },
              ),

              // Date de début
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Date de Début',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: tontineTextColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () => _selectDate(context),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: tontineWhite,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today, color: tontinePrimaryColor),
                          const SizedBox(width: 12),
                          Text(
                            displayedDate,
                            style: const TextStyle(fontSize: 16),
                          ),
                          const Spacer(),
                          Text(
                            'Modifier',
                            style: TextStyle(
                              color: tontinePrimaryColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

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
    super.dispose();
  }
}