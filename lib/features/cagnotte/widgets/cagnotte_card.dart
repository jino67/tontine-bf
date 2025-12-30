import 'package:flutter/material.dart';
import 'package:app_tontine_bf/config/theme.dart';
import 'package:app_tontine_bf/features/cagnotte/models/cagnotte_model.dart';

class CagnotteCard extends StatelessWidget {
  final Cagnotte cagnotte;
  final VoidCallback onTap;

  const CagnotteCard({
    super.key,
    required this.cagnotte,
    required this.onTap,
  });

  Color _getTypeColor() {
    switch (cagnotte.type) {
      case CagnotteType.flash24h:
        return tontineAccentColor;
      case CagnotteType.hebdo7j:
        return tontinePrimaryDark;
      case CagnotteType.mensuelle30j:
        return tontineGold;
    }
  }

  String _getTypeIcon() {
    switch (cagnotte.type) {
      case CagnotteType.flash24h:
        return '⚡';
      case CagnotteType.hebdo7j:
        return '📅';
      case CagnotteType.mensuelle30j:
        return '🏆';
    }
  }

  @override
  Widget build(BuildContext context) {
    final typeColor = _getTypeColor();
    final typeIcon = _getTypeIcon();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // En-tête avec nom et type
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
                      color: typeColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          typeIcon,
                          style: const TextStyle(fontSize: 12),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          cagnotte.typeString,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: typeColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Statut et participants
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: cagnotte.estTerminee
                          ? Colors.grey.withOpacity(0.2)
                          : Colors.green.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      cagnotte.statusString,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: cagnotte.estTerminee ? Colors.grey : Colors.green,
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

              // Montant total et gains
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
                          color: tontineTextColor,
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
                        'Gains jusqu\'à ${_getMaxGain()} FCFA',
                        style: TextStyle(
                          fontSize: 11,
                          color: tontineTextLight,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Temps restant et participation
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 16,
                        color: cagnotte.tempsRestant < 3600 ? Colors.orange : tontineTextLight,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        cagnotte.tempsRestantFormate,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: cagnotte.tempsRestant < 3600 ? Colors.orange : tontineTextLight,
                        ),
                      ),
                    ],
                  ),
                  if (cagnotte.dejaParticipe)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: tontinePrimaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check_circle,
                            size: 14,
                            color: tontinePrimaryColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Déjà participé',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: tontinePrimaryColor,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: tontineAccentColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Participer',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: tontineWhite,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getMaxGain() {
    if (cagnotte.gainsPotentiels.isNotEmpty) {
      final maxGain = cagnotte.gainsPotentiels.values.reduce((a, b) => a > b ? a : b);
      return maxGain.toStringAsFixed(0);
    }
    return '0';
  }
}