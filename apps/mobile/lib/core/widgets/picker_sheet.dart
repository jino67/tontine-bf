import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// Liste de choix en feuille basse. Retourne l'élément touché, ou null si la feuille est fermée.
Future<T?> showPickerSheet<T>(
  BuildContext context, {
  required String title,
  required List<T> items,
  required String Function(T item) label,
  String Function(T item)? subtitle,
  Widget Function(T item)? leading,
  String emptyMessage = 'Aucun choix disponible.',
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    builder: (context) {
      final theme = Theme.of(context);
      return ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.75),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text(title, style: theme.textTheme.titleLarge),
            ),
            if (items.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                child: Text(emptyMessage, style: theme.textTheme.bodyLarge?.copyWith(color: AppColors.muted)),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.only(bottom: 24),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const Divider(indent: 24, endIndent: 24),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                      leading: leading?.call(item),
                      title: Text(label(item)),
                      subtitle: subtitle == null ? null : Text(subtitle(item)),
                      onTap: () => Navigator.of(context).pop(item),
                    );
                  },
                ),
              ),
          ],
        ),
      );
    },
  );
}
