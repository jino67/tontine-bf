// lib/features/cagnotte/widgets/ticket_counter.dart
import 'package:flutter/material.dart';
import 'package:app_tontine_bf/config/theme.dart';

class TicketCounter extends StatelessWidget {
  final int nombreTickets;
  final double montantTotal;

  const TicketCounter({
    super.key,
    required this.nombreTickets,
    required this.montantTotal,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [tontinePrimaryColor.withOpacity(0.1), tontineAccentColor.withOpacity(0.1)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: tontinePrimaryColor.withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Vos tickets',
                style: TextStyle(
                  fontSize: 14,
                  color: tontineTextLight,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    Icons.confirmation_number,
                    size: 20,
                    color: tontinePrimaryColor,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$nombreTickets ticket${nombreTickets > 1 ? 's' : ''}',
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Investissement',
                style: TextStyle(
                  fontSize: 14,
                  color: tontineTextLight,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${montantTotal.toStringAsFixed(0)} FCFA',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: tontineTextColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}