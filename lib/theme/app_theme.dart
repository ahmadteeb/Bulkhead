import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // Light Colors
  static const Color primary = Color(0xFF006686);
  static const Color primaryContainer = Color(0xFF0DB7ED);
  static const Color onPrimaryContainer = Color(0xFF00445B);

  static const Color background = Color(0xFFF7F9FB);
  static const Color surface = Color(0xFFF7F9FB);
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color surfaceContainerLow = Color(0xFFF2F4F6);
  static const Color surfaceContainer = Color(0xFFF1F5F9);
  static const Color surfaceContainerHigh = Color(0xFFE6E8EA);
  static const Color surfaceBorder = Color(0xFFE2E8F0);

  static const Color onSurface = Color(0xFF191C1E);
  static const Color onSurfaceVariant = Color(0xFF3D484F);
  static const Color onSurfaceMuted = Color(0xFF64748B);

  // Dark Colors
  static const Color darkBackground = Color(0xFF111316);
  static const Color darkSurfaceContainerLowest = Color(0xFF0C0E11);
  static const Color darkSurfaceContainerLow = Color(0xFF1A1C1F);
  static const Color darkSurfaceContainer = Color(0xFF1E2023);
  static const Color darkSurfaceContainerHigh = Color(0xFF282A2D);
  static const Color darkSurfaceBorder = Color(0xFF3D484F);

  static const Color darkOnSurface = Color(0xFFE2E2E6);
  static const Color darkOnSurfaceVariant = Color(0xFFBCC8D0);
  static const Color darkOnSurfaceMuted = Color(0xFF87929A);

  static const Color darkPrimary = Color(0xFF70D2FF);
  static const Color darkPrimaryContainer = Color(0xFF0DB7ED);
  static const Color darkOnPrimaryContainer = Color(0xFF00445B);

  // Semantics
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color inactive = Color(0xFF87929A);

  static bool isDark(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark;
  }

  static Color cardBg(BuildContext context) {
    return isDark(context)
        ? darkSurfaceContainerLowest
        : surfaceContainerLowest;
  }

  static Color sidebarBg(BuildContext context) {
    return isDark(context) ? darkSurfaceContainer : surfaceContainer;
  }

  static Color borderColor(BuildContext context) {
    return isDark(context) ? darkSurfaceBorder : surfaceBorder;
  }

  static Color containerLow(BuildContext context) {
    return isDark(context) ? darkSurfaceContainerLow : surfaceContainerLow;
  }
}

class AppTheme {
  static TextStyle _fontStyle({
    required double fontSize,
    required FontWeight fontWeight,
    required Color color,
    double? letterSpacing,
  }) {
    try {
      return GoogleFonts.hankenGrotesk(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        letterSpacing: letterSpacing,
      );
    } catch (_) {
      return TextStyle(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        letterSpacing: letterSpacing,
      );
    }
  }

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        primaryContainer: AppColors.primaryContainer,
        onPrimaryContainer: AppColors.onPrimaryContainer,
        surface: AppColors.surfaceContainerLowest,
        onSurface: AppColors.onSurface,
        onSurfaceVariant: AppColors.onSurfaceVariant,
        outline: AppColors.surfaceBorder,
        error: AppColors.error,
      ),
      textTheme: TextTheme(
        headlineLarge: _fontStyle(
          fontSize: 32,
          fontWeight: FontWeight.w600,
          color: AppColors.onSurface,
          letterSpacing: -0.5,
        ),
        headlineMedium: _fontStyle(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: AppColors.onSurface,
        ),
        titleMedium: _fontStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppColors.onSurface,
        ),
        bodyMedium: _fontStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: AppColors.onSurface,
        ),
        bodySmall: _fontStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: AppColors.onSurfaceMuted,
        ),
        labelSmall: _fontStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
          color: AppColors.onSurfaceMuted,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.surfaceBorder,
        thickness: 1,
        space: 1,
      ),
      cardTheme: CardThemeData(
        color: AppColors.surfaceContainerLowest,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.surfaceBorder),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceContainerLowest,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.surfaceBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.surfaceBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(
            color: AppColors.primaryContainer,
            width: 2,
          ),
        ),
        hintStyle: const TextStyle(
          color: AppColors.onSurfaceMuted,
          fontSize: 14,
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.darkBackground,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.darkPrimary,
        primaryContainer: AppColors.darkPrimaryContainer,
        onPrimaryContainer: AppColors.darkOnPrimaryContainer,
        surface: AppColors.darkSurfaceContainerLowest,
        onSurface: AppColors.darkOnSurface,
        onSurfaceVariant: AppColors.darkOnSurfaceVariant,
        outline: AppColors.darkSurfaceBorder,
        error: AppColors.error,
      ),
      textTheme: TextTheme(
        headlineLarge: _fontStyle(
          fontSize: 32,
          fontWeight: FontWeight.w600,
          color: AppColors.darkOnSurface,
          letterSpacing: -0.5,
        ),
        headlineMedium: _fontStyle(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: AppColors.darkOnSurface,
        ),
        titleMedium: _fontStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppColors.darkOnSurface,
        ),
        bodyMedium: _fontStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: AppColors.darkOnSurface,
        ),
        bodySmall: _fontStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: AppColors.darkOnSurfaceMuted,
        ),
        labelSmall: _fontStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
          color: AppColors.darkOnSurfaceMuted,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.darkSurfaceBorder,
        thickness: 1,
        space: 1,
      ),
      cardTheme: CardThemeData(
        color: AppColors.darkSurfaceContainerLowest,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.darkSurfaceBorder),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.darkSurfaceContainerLowest,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.darkSurfaceBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.darkSurfaceBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.darkPrimary, width: 2),
        ),
        hintStyle: const TextStyle(
          color: AppColors.darkOnSurfaceMuted,
          fontSize: 14,
        ),
      ),
    );
  }
}
