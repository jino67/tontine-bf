import 'package:flutter/material.dart';
import 'package:app_tontine_bf/config/theme.dart';

class MontantSelector extends StatefulWidget {
  final List<double> montants;
  final double montantMin;
  final bool accepteMontantsLibres;
  final double selectedMontant;
  final ValueChanged<double> onMontantChanged;

  const MontantSelector({
    super.key,
    required this.montants,
    required this.montantMin,
    required this.accepteMontantsLibres,
    required this.selectedMontant,
    required this.onMontantChanged,
  });

  @override
  State<MontantSelector> createState() => _MontantSelectorState();
}

class _MontantSelectorState extends State<MontantSelector> {
  final TextEditingController _customAmountController = TextEditingController();
  bool _isCustomAmount = false;

  @override
  void initState() {
    super.initState();
    // Vérifier si le montant sélectionné est dans la liste prédéfinie
    _isCustomAmount = !widget.montants.contains(widget.selectedMontant) &&
        widget.selectedMontant > 0;

    if (_isCustomAmount) {
      _customAmountController.text = widget.selectedMontant.toStringAsFixed(0);
    }
  }

  @override
  void dispose() {
    _customAmountController.dispose();
    super.dispose();
  }

  void _handleMontantSelection(double montant) {
    setState(() {
      _isCustomAmount = false;
      _customAmountController.clear();
    });
    widget.onMontantChanged(montant);
  }

  void _handleCustomAmount(String value) {
    if (value.isEmpty) return;

    try {
      final montant = double.parse(value);
      if (montant >= widget.montantMin) {
        setState(() {
          _isCustomAmount = true;
        });
        widget.onMontantChanged(montant);
      }
    } catch (e) {
      // Ignorer les entrées invalides
    }
  }

  Widget _buildMontantChip(double montant) {
    final isSelected = !_isCustomAmount && widget.selectedMontant == montant;
    final tickets = (montant / 250).floor();

    return GestureDetector(
      onTap: () => _handleMontantSelection(montant),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? tontinePrimaryColor : tontinePrimaryColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? tontinePrimaryColor : tontinePrimaryColor.withOpacity(0.3),
            width: 2,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${montant.toStringAsFixed(0)} FCFA',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isSelected ? tontineWhite : tontinePrimaryColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '$tickets ticket${tickets > 1 ? 's' : ''}',
              style: TextStyle(
                fontSize: 11,
                color: isSelected ? tontineWhite.withOpacity(0.8) : tontineTextLight,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomAmountField() {
    final isSelected = _isCustomAmount;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isSelected ? tontinePrimaryColor.withOpacity(0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? tontinePrimaryColor : Colors.grey.withOpacity(0.3),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.edit,
                size: 16,
                color: isSelected ? tontinePrimaryColor : tontineTextLight,
              ),
              const SizedBox(width: 8),
              Text(
                'Montant personnalisé',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? tontinePrimaryColor : tontineTextColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _customAmountController,
            decoration: InputDecoration(
              hintText: 'Entrez un montant (min ${widget.montantMin} FCFA)',
              hintStyle: TextStyle(
                color: tontineTextLight,
                fontSize: 14,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: tontinePrimaryColor.withOpacity(0.3),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: tontinePrimaryColor,
                  width: 2,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              prefixIcon: Icon(
                Icons.attach_money,
                size: 20,
                color: tontineTextLight,
              ),
              suffixText: 'FCFA',
              suffixStyle: TextStyle(
                color: tontineTextLight,
              ),
            ),
            keyboardType: TextInputType.number,
            style: TextStyle(
              fontSize: 14,
              color: tontineTextColor,
            ),
            onChanged: _handleCustomAmount,
          ),
          if (_customAmountController.text.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Tickets: ${(_getCustomAmount() / 250).floor()}',
                style: TextStyle(
                  fontSize: 12,
                  color: tontineTextLight,
                ),
              ),
            ),
        ],
      ),
    );
  }

  double _getCustomAmount() {
    try {
      return double.parse(_customAmountController.text);
    } catch (e) {
      return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Montants prédéfinis
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: widget.montants.map(_buildMontantChip).toList(),
        ),

        const SizedBox(height: 16),

        // Séparateur
        if (widget.accepteMontantsLibres)
          Row(
            children: [
              Expanded(
                child: Divider(
                  color: tontineTextLight.withOpacity(0.3),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'OU',
                  style: TextStyle(
                    fontSize: 12,
                    color: tontineTextLight,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Expanded(
                child: Divider(
                  color: tontineTextLight.withOpacity(0.3),
                ),
              ),
            ],
          ),

        const SizedBox(height: 16),

        // Montant personnalisé
        if (widget.accepteMontantsLibres)
          _buildCustomAmountField()
        else
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 16,
                  color: tontineTextLight,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Montants fixes uniquement pour cette cagnotte',
                    style: TextStyle(
                      fontSize: 12,
                      color: tontineTextLight,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}