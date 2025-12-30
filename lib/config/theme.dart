import 'package:flutter/material.dart';

// Nouveau thème Burkina Faso - Rouge clair + Vert trop clair
// Palette mise à jour inspirée du logo
const Color tontinePrimaryColor = Color(0xFF4CAF50); // Vert profond élégant (remplace le rouge)
const Color tontinePrimaryDark = Color(0xFF388E3C); // Vert foncé pour les éléments actifs
const Color tontineAccentColor = Color(0xFFFFD700); // Or (zigzag du logo)
const Color tontineAccentDark = Color(0xFFC0A000); // Or foncé pour hover ou focus
const Color tontineBackgroundColor = Color(0xFFF8F9FA); // Gris très clair (inchangé)
const Color tontineTextColor = Color(0xFF212529); // Gris anthracite (plus doux que noir pur)
const Color tontineTextLight = Color(0xFF6C757D); // Gris moyen (inchangé)
const Color tontineWhite = Color(0xFFFFFFFF); // Blanc (inchangé)
const Color tontineGold = Color(0xFFFFD700); // Or (inchangé)


final ThemeData tontineTheme = ThemeData.light().copyWith(
  // 1. Définition explicite du ColorScheme (méthode moderne)
  colorScheme: ColorScheme.light(
    primary: tontinePrimaryColor,
    secondary: tontineAccentColor,
    surface: tontineWhite,
    background: tontineBackgroundColor,
    error: Colors.red,
    onPrimary: tontineWhite,
    onSecondary: tontineTextColor,
    onSurface: tontineTextColor,
    onBackground: tontineTextColor,
    onError: tontineWhite,
    brightness: Brightness.light,
  ),

  // Couleurs de base restantes
  scaffoldBackgroundColor: tontineBackgroundColor,

  // Thème de l'AppBar
  appBarTheme: const AppBarTheme(
    backgroundColor: tontinePrimaryColor,
    foregroundColor: tontineWhite,
    elevation: 0,
    centerTitle: true,
    titleTextStyle: TextStyle(
      color: tontineWhite,
      fontSize: 20,
      fontWeight: FontWeight.bold,
    ),
    iconTheme: IconThemeData(color: tontineWhite),
  ),

  // Thème des boutons
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      // Utilisation du colorScheme.primary via les valeurs par défaut
      // Sinon, on peut utiliser des champs spécifiques pour les couleurs si elles diffèrent du colorScheme
      backgroundColor: tontinePrimaryColor, // CORRIGÉ: Utilise backgroundColor pour la couleur du bouton
      foregroundColor: tontineWhite,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      textStyle: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
      elevation: 2,
    ),
  ),

  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: tontinePrimaryColor,
      textStyle: const TextStyle(
        fontWeight: FontWeight.w600,
      ),
    ),
  ),

  // Thème des TextFields
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: tontineWhite,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: tontinePrimaryColor, width: 2),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    labelStyle: const TextStyle(color: tontineTextLight),
    floatingLabelStyle: const TextStyle(color: tontinePrimaryColor),
    prefixIconColor: MaterialStateColor.resolveWith((states) {
      if (states.contains(MaterialState.focused)) {
        return tontinePrimaryColor;
      }
      return tontineTextLight;
    }),
  ),

  // Autres
  floatingActionButtonTheme: const FloatingActionButtonThemeData(
    backgroundColor: tontinePrimaryColor,
    foregroundColor: tontineWhite,
  ),
);

// Styles de texte personnalisés
class AppTextStyles {
  static const TextStyle titleLarge = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    color: tontineTextColor,
  );

  static const TextStyle titleMedium = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.bold,
    color: tontineTextColor,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    color: tontineTextColor,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    color: tontineTextLight,
  );

  static const TextStyle button = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: tontineWhite,
  );
}

// Box Shadows
class AppShadows {
  static List<BoxShadow> get cardShadow {
    return [
      BoxShadow(
        color: Colors.black.withOpacity(0.1),
        blurRadius: 10,
        spreadRadius: 2,
        offset: const Offset(0, 2),
      ),
    ];
  }

  static List<BoxShadow> get buttonShadow {
    return [
      BoxShadow(
        color: tontinePrimaryColor.withOpacity(0.3),
        blurRadius: 10,
        spreadRadius: 2,
        offset: const Offset(0, 3),
      ),
    ];
  }
}

// Style de carte personnalisé pour remplacer cardTheme
class AppCardStyle {
  static BoxDecoration get cardDecoration {
    return BoxDecoration(
      color: tontineWhite,
      borderRadius: BorderRadius.circular(16),
      boxShadow: AppShadows.cardShadow,
    );
  }

  static EdgeInsets get cardPadding {
    return const EdgeInsets.all(16);
  }
}