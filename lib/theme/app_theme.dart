import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'design_tokens.dart';

class AppColors {
  // Light Colors
  static const Color primary = DesignTokens.blue;
  static const Color primaryContainer = DesignTokens.blue;
  static const Color onPrimaryContainer = Colors.white;

  static const Color background = DesignTokens.canvas;
  static const Color surface = DesignTokens.canvas;
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color surfaceContainerLow = Color(0xFFF2F4F6);
  static const Color surfaceContainer = Color(0xFFEBF0F8);
  static const Color surfaceContainerHigh = Color(0xFFE6E8EA);
  static const Color surfaceBorder = DesignTokens.line;

  static const Color onSurface = DesignTokens.ink;
  static const Color onSurfaceVariant = DesignTokens.slate;
  static const Color onSurfaceMuted = Color(0xFF64748B);

  // Dark Colors
  static const Color darkBackground = DesignTokens.navy;
  static const Color darkSurfaceContainerLowest = DesignTokens.navyRaised;
  static const Color darkSurfaceContainerLow = Color(0xFF1C293D);
  static const Color darkSurfaceContainer = Color(0xFF121D2E);
  static const Color darkSurfaceContainerHigh = Color(0xFF25344B);
  static const Color darkSurfaceBorder = DesignTokens.lineDark;

  static const Color darkOnSurface = Color(0xFFE2E2E6);
  static const Color darkOnSurfaceVariant = Color(0xFFBCC8D0);
  static const Color darkOnSurfaceMuted = Color(0xFF9BAEC8);

  static const Color darkPrimary = DesignTokens.blueLight;
  static const Color darkPrimaryContainer = DesignTokens.blue;
  static const Color darkOnPrimaryContainer = Colors.white;

  // Semantics
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color inactive = Color(0xFF9BAEC8);

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

  static ThemeData _components(ThemeData theme) {
    final scheme = theme.colorScheme;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(DesignTokens.controlRadius),
    );
    return theme.copyWith(
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(0, DesignTokens.controlHeight),
          backgroundColor: scheme.primaryContainer,
          foregroundColor: scheme.onPrimaryContainer,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: shape,
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, DesignTokens.controlHeight),
          foregroundColor: scheme.onSurface,
          side: BorderSide(color: scheme.outline),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: shape,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(shape: shape),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(shape: shape),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DesignTokens.panelRadius),
        ),
      ),
      tooltipTheme: const TooltipThemeData(
        waitDuration: Duration(milliseconds: 350),
      ),
    );
  }

  static ThemeData get lightTheme {
    return _components(
      ThemeData(
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
      ),
    );
  }

  static ThemeData get darkTheme {
    return _components(
      ThemeData(
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
            borderSide: const BorderSide(
              color: AppColors.darkPrimary,
              width: 2,
            ),
          ),
          hintStyle: const TextStyle(
            color: AppColors.darkOnSurfaceMuted,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}
