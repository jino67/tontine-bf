import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Vert et or du logo, indigo du Faso Dan Fani pour tout ce qui touche au tirage.
abstract final class AppColors {
  static const ink = Color(0xFF12352A);
  static const leaf = Color(0xFF1E7A4C);
  static const leafDeep = Color(0xFF155C39);
  static const leafSoft = Color(0xFFDDEFE3);
  static const gold = Color(0xFFE0A526);
  static const goldText = Color(0xFF8A5A00);
  static const goldSoft = Color(0xFFFBEFD0);
  static const indigo = Color(0xFF2F3E8F);
  static const indigoSoft = Color(0xFFE3E6F5);
  static const chili = Color(0xFFB83227);
  static const chiliSoft = Color(0xFFF8E1DE);
  static const cotton = Color(0xFFF3F6F1);
  static const line = Color(0xFFD5DED6);
  static const muted = Color(0xFF55655D);
}

/// Charte typographique.
///
/// Titres : Young Serif, une seule graisse. La hiérarchie se fait par la taille, jamais par un faux gras.
/// Texte, boutons, montants et codes : Atkinson Hyperlegible, dessinée pour la lisibilité (0 et O, 1 et I bien distincts).
///
/// google_fonts enregistre chaque graisse comme une police à part : pour du gras, passer par [sans] avec bold,
/// et non par copyWith(fontWeight:), qui produirait un gras synthétique.
abstract final class AppType {
  static const tabularFigures = [FontFeature.tabularFigures()];

  static TextStyle serif(double size, {Color color = AppColors.ink, double height = 1.15, double letterSpacing = 0}) =>
      GoogleFonts.youngSerif(fontSize: size, color: color, height: height, letterSpacing: letterSpacing);

  static TextStyle sans({
    double size = 16,
    bool bold = false,
    Color color = AppColors.ink,
    double height = 1.4,
    double letterSpacing = 0,
    bool tabular = false,
  }) =>
      GoogleFonts.atkinsonHyperlegible(
        fontSize: size,
        fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
        color: color,
        height: height,
        letterSpacing: letterSpacing,
        fontFeatures: tabular ? tabularFigures : null,
      );

  /// Codes à saisir ou à recopier (OTP, invitation).
  static TextStyle code(double size, {Color color = AppColors.ink, double letterSpacing = 6}) =>
      sans(size: size, bold: true, color: color, letterSpacing: letterSpacing, height: 1.2, tabular: true);
}

abstract final class AppTheme {
  static const tabularFigures = AppType.tabularFigures;

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.leaf,
      primary: AppColors.leaf,
      onPrimary: Colors.white,
      secondary: AppColors.gold,
      onSecondary: AppColors.ink,
      tertiary: AppColors.indigo,
      error: AppColors.chili,
      surface: Colors.white,
      onSurface: AppColors.ink,
    );

    final text = TextTheme(
      displayLarge: AppType.serif(52, height: 1.05, letterSpacing: -1),
      displayMedium: AppType.serif(44, height: 1.05, letterSpacing: -0.8),
      displaySmall: AppType.serif(36, height: 1.08, letterSpacing: -0.5),
      headlineLarge: AppType.serif(32),
      headlineMedium: AppType.serif(28),
      headlineSmall: AppType.serif(24),
      titleLarge: AppType.serif(21, height: 1.2),
      titleMedium: AppType.sans(size: 17, bold: true, height: 1.3),
      titleSmall: AppType.sans(size: 15, bold: true, height: 1.3),
      bodyLarge: AppType.sans(size: 16, height: 1.45),
      bodyMedium: AppType.sans(size: 15, height: 1.45),
      bodySmall: AppType.sans(size: 13, color: AppColors.muted, height: 1.35),
      labelLarge: AppType.sans(size: 15, bold: true),
      labelMedium: AppType.sans(size: 13, bold: true),
      labelSmall: AppType.sans(size: 12, bold: true),
    );

    final radius12 = BorderRadius.circular(12);
    final radius14 = BorderRadius.circular(14);
    final buttonText = AppType.sans(size: 16, bold: true);

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: AppType.sans().fontFamily,
      textTheme: text,
      scaffoldBackgroundColor: AppColors.cotton,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.cotton,
        foregroundColor: AppColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: AppType.serif(22),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: AppColors.line)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 52),
          shape: RoundedRectangleBorder(borderRadius: radius14),
          textStyle: buttonText,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 52),
          foregroundColor: AppColors.ink,
          side: const BorderSide(color: AppColors.line, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: radius14),
          textStyle: buttonText,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.leaf,
          minimumSize: const Size(48, 48),
          textStyle: AppType.sans(size: 15, bold: true),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.leaf,
        foregroundColor: Colors.white,
        extendedTextStyle: buttonText,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(borderRadius: radius12, borderSide: const BorderSide(color: AppColors.line)),
        enabledBorder: OutlineInputBorder(borderRadius: radius12, borderSide: const BorderSide(color: AppColors.line)),
        focusedBorder: OutlineInputBorder(borderRadius: radius12, borderSide: const BorderSide(color: AppColors.leaf, width: 2)),
        errorBorder: OutlineInputBorder(borderRadius: radius12, borderSide: const BorderSide(color: AppColors.chili)),
        focusedErrorBorder: OutlineInputBorder(borderRadius: radius12, borderSide: const BorderSide(color: AppColors.chili, width: 2)),
        labelStyle: AppType.sans(color: AppColors.muted),
        floatingLabelStyle: AppType.sans(bold: true, color: AppColors.leaf),
        hintStyle: AppType.sans(color: const Color(0xFF9AA8A0)),
        helperStyle: AppType.sans(size: 13, color: AppColors.muted),
        errorStyle: AppType.sans(size: 13, color: AppColors.chili),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.white,
        selectedColor: AppColors.leafSoft,
        side: const BorderSide(color: AppColors.line),
        shape: const StadiumBorder(),
        labelStyle: AppType.sans(size: 15, bold: true),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: AppColors.leafSoft,
        height: 68,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => AppType.sans(size: 12, bold: states.contains(WidgetState.selected)),
        ),
      ),
      dividerTheme: const DividerThemeData(color: AppColors.line, thickness: 1, space: 1),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.ink,
        contentTextStyle: AppType.sans(size: 15, color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: radius12),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        showDragHandle: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        titleTextStyle: AppType.serif(22),
        contentTextStyle: AppType.sans(size: 16, color: AppColors.ink),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: AppColors.muted,
        minVerticalPadding: 12,
        titleTextStyle: AppType.sans(size: 16, bold: true),
        subtitleTextStyle: AppType.sans(size: 14, color: AppColors.muted),
      ),
      expansionTileTheme: const ExpansionTileThemeData(
        shape: Border(),
        collapsedShape: Border(),
        iconColor: AppColors.leaf,
        collapsedIconColor: AppColors.muted,
      ),
    );
  }
}
