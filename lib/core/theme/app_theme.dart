import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'incline_colors.dart';
export 'incline_colors.dart';
export 'incline_ui.dart';

/// Pure Material 3 Design System for Incline
/// STRICT DESIGN SYSTEM: MONOCHROME CARBON & THERMAL ORANGE
class AppTheme {
  // Mandatory InclineColors Design System Tokens
  static const Color primaryForest = InclineColors.accentOrange;
  static const Color gold = InclineColors.accentOrange;
  static const Color goldLight = InclineColors.thermalAmber;
  static const Color goldDark = InclineColors.thermalRed;
  
  static const Color background = InclineColors.bgPrimary;
  static const Color surface = InclineColors.cardSurface;
  static const Color surfaceElevated = InclineColors.cardRecessed;
  static const Color surfaceHighlight = InclineColors.heroSpotlight;
  
  static const Color border = InclineColors.cardBorder;
  static const Color borderLight = InclineColors.glassBorderHighlight;
  
  static const Color textPrimary = InclineColors.textPrimary;
  static const Color textSecondary = InclineColors.textSecondary;
  static const Color textMuted = InclineColors.textMuted;

  static const Color emerald = InclineColors.accentOrange;
  static const Color amber = InclineColors.thermalAmber;
  static const Color rose = InclineColors.thermalRed;
  static const Color cyan = InclineColors.accentOrange;
  static const Color sky = InclineColors.accentOrange;

  // Light Mode Palette (Crisp White Canvas with Incline Thermal Accents)
  static const Color lightBackground = InclineColors.lightBgPrimary;
  static const Color lightSurface = InclineColors.lightCardSurface;
  static const Color lightSurfaceElevated = InclineColors.lightCardRecessed;
  static const Color lightSurfaceHighlight = InclineColors.lightHeroSpotlight;

  static const Color lightBorder = InclineColors.lightCardBorder;
  static const Color lightBorderLight = InclineColors.lightGlassBorderHighlight;

  static const Color lightTextPrimary = InclineColors.lightTextPrimary;
  static const Color lightTextSecondary = InclineColors.lightTextSecondary;
  static const Color lightTextMuted = InclineColors.lightTextMuted;

  static ThemeData get darkTheme {
    final baseTextTheme = ThemeData.dark().textTheme;
    final textTheme = GoogleFonts.outfitTextTheme(baseTextTheme).copyWith(
      displayLarge: GoogleFonts.outfit(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        color: textPrimary,
        letterSpacing: -0.5,
      ),
      displayMedium: GoogleFonts.outfit(
        fontSize: 26,
        fontWeight: FontWeight.w700,
        color: textPrimary,
        letterSpacing: -0.3,
      ),
      titleLarge: GoogleFonts.outfit(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      ),
      titleMedium: GoogleFonts.outfit(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      ),
      titleSmall: GoogleFonts.outfit(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: textSecondary,
      ),
      bodyLarge: GoogleFonts.outfit(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: textPrimary,
      ),
      bodyMedium: GoogleFonts.outfit(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: textSecondary,
      ),
      bodySmall: GoogleFonts.outfit(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: textMuted,
      ),
      labelLarge: GoogleFonts.outfit(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: textPrimary,
        letterSpacing: 0.5,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      dividerColor: border,
      colorScheme: const ColorScheme.dark(
        primary: InclineColors.accentOrange,
        onPrimary: InclineColors.textPrimary,
        primaryContainer: InclineColors.cardRecessed,
        onPrimaryContainer: InclineColors.accentOrange,
        secondary: InclineColors.thermalAmber,
        onSecondary: InclineColors.textPrimary,
        secondaryContainer: InclineColors.cardRecessed,
        onSecondaryContainer: InclineColors.thermalAmber,
        tertiary: InclineColors.thermalRed,
        onTertiary: InclineColors.textPrimary,
        tertiaryContainer: InclineColors.cardRecessed,
        onTertiaryContainer: InclineColors.thermalRed,
        surface: InclineColors.cardSurface,
        onSurface: InclineColors.textPrimary,
        onSurfaceVariant: InclineColors.textSecondary,
        surfaceContainerLowest: InclineColors.bgPrimary,
        surfaceContainerLow: InclineColors.cardSurface,
        surfaceContainer: InclineColors.cardSurface,
        surfaceContainerHigh: InclineColors.cardRecessed,
        surfaceContainerHighest: InclineColors.heroSpotlight,
        outline: InclineColors.cardBorder,
        outlineVariant: InclineColors.glassBorderHighlight,
        error: InclineColors.thermalRed,
        onError: InclineColors.textPrimary,
      ),
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.outfit(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: textPrimary,
          letterSpacing: -0.2,
        ),
        iconTheme: const IconThemeData(color: textPrimary),
      ),
      cardTheme: CardTheme(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: border, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: gold,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: GoogleFonts.outfit(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          side: const BorderSide(color: borderLight, width: 1.2),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: GoogleFonts.outfit(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: gold,
          textStyle: GoogleFonts.outfit(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceElevated,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: gold, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: rose, width: 1.5),
        ),
        hintStyle: GoogleFonts.outfit(color: textMuted, fontSize: 14),
        labelStyle: GoogleFonts.outfit(color: textSecondary, fontSize: 14),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surfaceElevated,
        indicatorColor: gold.withValues(alpha: 0.18),
        surfaceTintColor: Colors.transparent,
        elevation: 4,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: gold,
            );
          }
          return GoogleFonts.outfit(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: textMuted,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: gold, size: 24);
          }
          return const IconThemeData(color: textMuted, size: 24);
        }),
      ),
      dividerTheme: const DividerThemeData(
        color: border,
        thickness: 1,
        space: 24,
      ),
    );
  }

  static ThemeData get lightTheme {
    final baseTextTheme = ThemeData.light().textTheme;
    final textTheme = GoogleFonts.outfitTextTheme(baseTextTheme).copyWith(
      displayLarge: GoogleFonts.outfit(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        color: lightTextPrimary,
        letterSpacing: -0.5,
      ),
      displayMedium: GoogleFonts.outfit(
        fontSize: 26,
        fontWeight: FontWeight.w700,
        color: lightTextPrimary,
        letterSpacing: -0.3,
      ),
      titleLarge: GoogleFonts.outfit(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: lightTextPrimary,
      ),
      titleMedium: GoogleFonts.outfit(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: lightTextPrimary,
      ),
      titleSmall: GoogleFonts.outfit(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: lightTextSecondary,
      ),
      bodyLarge: GoogleFonts.outfit(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: lightTextPrimary,
      ),
      bodyMedium: GoogleFonts.outfit(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: lightTextSecondary,
      ),
      bodySmall: GoogleFonts.outfit(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: lightTextMuted,
      ),
      labelLarge: GoogleFonts.outfit(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: lightTextPrimary,
        letterSpacing: 0.5,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: lightBackground,
      dividerColor: lightBorder,
      colorScheme: const ColorScheme.light(
        primary: InclineColors.accentOrange,
        onPrimary: Colors.white,
        primaryContainer: InclineColors.lightCardRecessed,
        onPrimaryContainer: InclineColors.accentOrange,
        secondary: InclineColors.thermalAmber,
        onSecondary: Colors.white,
        secondaryContainer: InclineColors.lightCardRecessed,
        onSecondaryContainer: InclineColors.thermalAmber,
        tertiary: InclineColors.thermalRed,
        onTertiary: Colors.white,
        tertiaryContainer: InclineColors.lightCardRecessed,
        onTertiaryContainer: InclineColors.thermalRed,
        surface: InclineColors.lightCardSurface,
        onSurface: InclineColors.lightTextPrimary,
        onSurfaceVariant: InclineColors.lightTextSecondary,
        outline: InclineColors.lightCardBorder,
        outlineVariant: InclineColors.lightGlassBorderSubtle,
        error: InclineColors.thermalRed,
        onError: Colors.white,
      ),
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: lightBackground,
        foregroundColor: lightTextPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: GoogleFonts.outfit(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: lightTextPrimary,
        ),
      ),
      cardTheme: CardTheme(
        color: lightSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: lightBorder, width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: InclineColors.accentOrange,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.outfit(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: lightSurfaceElevated,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: lightBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: lightBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: InclineColors.accentOrange, width: 1.5),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: lightBorder,
        thickness: 1,
        space: 24,
      ),
    );
  }

  // --- Dynamic Theme Helpers ---
  static Color getBackground(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? InclineColors.bgPrimary : InclineColors.lightBgPrimary;

  static Color getSurface(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? InclineColors.cardSurface : InclineColors.lightCardSurface;

  static Color getSurfaceElevated(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? InclineColors.cardRecessed : InclineColors.lightCardRecessed;

  static Color getSurfaceHighlight(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? InclineColors.heroSpotlight : InclineColors.lightHeroSpotlight;

  static Color getBorder(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? InclineColors.cardBorder : InclineColors.lightCardBorder;

  static Color getTextPrimary(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? InclineColors.textPrimary : InclineColors.lightTextPrimary;

  static Color getTextSecondary(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? InclineColors.textSecondary : InclineColors.lightTextSecondary;

  static Color getTextMuted(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? InclineColors.textMuted : InclineColors.lightTextMuted;

  static Color getAccent(BuildContext context) => InclineColors.accentOrange;
}

/// Extension on BuildContext for effortless, central theme styling across all screens
extension InclineThemeX on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
  ThemeData get theme => Theme.of(this);
  ColorScheme get colorScheme => Theme.of(this).colorScheme;

  Color get bg => isDark ? InclineColors.bgPrimary : InclineColors.lightBgPrimary;
  Color get scaffoldBg => bg;
  Color get cardBg => isDark ? InclineColors.cardSurface : InclineColors.lightCardSurface;
  Color get cardElevated => isDark ? InclineColors.cardRecessed : InclineColors.lightCardRecessed;
  Color get borderCol => isDark ? InclineColors.cardBorder : InclineColors.lightCardBorder;
  Color get textPrimary => isDark ? InclineColors.textPrimary : InclineColors.lightTextPrimary;
  Color get textSecondary => isDark ? InclineColors.textSecondary : InclineColors.lightTextSecondary;
  Color get textMuted => isDark ? InclineColors.textMuted : InclineColors.lightTextMuted;
  Color get goldAccent => InclineColors.accentOrange;
  Color get brandAccent => InclineColors.accentOrange;
  Color get brandAccentLight => InclineColors.thermalAmber;
  Color get onBrandAccent => Colors.white;
  Color get emeraldAccent => InclineColors.accentOrange;

  // Centralized button styles matching active theme
  ButtonStyle get primaryBtnStyle => ElevatedButton.styleFrom(
        backgroundColor: brandAccent,
        foregroundColor: onBrandAccent,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w700),
      );

  ButtonStyle get secondaryBtnStyle => OutlinedButton.styleFrom(
        foregroundColor: brandAccent,
        side: BorderSide(color: brandAccent.withValues(alpha: 0.4), width: 1.2),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600),
      );

  // Centralized decorative container styles
  BoxDecoration get badgeDecoration => BoxDecoration(
        color: brandAccent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: brandAccent.withValues(alpha: 0.3)),
      );

  BoxDecoration get cardDecoration => BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderCol, width: 1),
      );

  BoxDecoration get accentIconBg => BoxDecoration(
        color: brandAccent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      );
}
