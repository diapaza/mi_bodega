import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Tema de MiBodega (Material 3) con los tokens de la F1.
class AppTheme {
  AppTheme._();

  static ThemeData light() => _build(AppColors.light);

  static ThemeData dark() => _build(AppColors.dark);

  static TextTheme _applyGoogleFonts(TextTheme base, Color onSurface) {
    return GoogleFonts.poppinsTextTheme(base)
        .apply(bodyColor: onSurface, displayColor: onSurface)
        .copyWith(
          headlineMedium: GoogleFonts.poppins(
            fontSize: base.headlineMedium?.fontSize,
            fontWeight: FontWeight.w700,
            color: onSurface,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
          titleLarge: GoogleFonts.poppins(
            fontSize: base.titleLarge?.fontSize,
            fontWeight: FontWeight.w700,
            color: onSurface,
          ),
          titleMedium: GoogleFonts.poppins(
            fontSize: base.titleMedium?.fontSize,
            fontWeight: FontWeight.w600,
            color: onSurface,
          ),
          titleSmall: GoogleFonts.poppins(
            fontSize: base.titleSmall?.fontSize,
            fontWeight: FontWeight.w600,
            color: onSurface,
          ),
          labelLarge: GoogleFonts.poppins(
            fontSize: base.labelLarge?.fontSize,
            fontWeight: FontWeight.w600,
            color: onSurface,
          ),
          labelMedium: GoogleFonts.poppins(
            fontSize: base.labelMedium?.fontSize,
            fontWeight: FontWeight.w600,
            color: onSurface,
          ),
        );
  }

  static ThemeData _build(AppColors c) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: c.primary,
      brightness: c == AppColors.light ? Brightness.light : Brightness.dark,
    ).copyWith(
      primary: c.primary,
      onPrimary: c.onPrimary,
      primaryContainer: c.primaryContainer,
      onPrimaryContainer: c.onPrimaryContainer,
      secondary: c.secondary,
      onSecondary: c.onSecondary,
      secondaryContainer: c.secondaryContainer,
      onSecondaryContainer: c.onSecondaryContainer,
      error: c.error,
      onError: c.onError,
      errorContainer: c.errorContainer,
      onErrorContainer: c.onErrorContainer,
      surface: c.surface,
      onSurface: c.onSurface,
      surfaceContainer: c.surfaceContainer,
      surfaceContainerHigh: c.surfaceVariant,
      surfaceContainerHighest: c.surfaceVariant,
      surfaceContainerLow: c.surfaceContainer,
      surfaceContainerLowest: c.surface,
      onSurfaceVariant: c.onSurfaceVariant,
      outline: c.outline,
      outlineVariant: c.outlineVariant,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: c.background,
    );

    final textTheme = _applyGoogleFonts(base.textTheme, c.onSurface);

    return base.copyWith(
      textTheme: textTheme,
      extensions: [c],
      appBarTheme: AppBarTheme(
        backgroundColor: c.surface,
        foregroundColor: c.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: c.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        color: c.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: c.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: c.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: c.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: c.error),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: c.surfaceContainer,
        indicatorColor: c.primaryContainer,
        surfaceTintColor: Colors.transparent,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: c.surfaceVariant,
        contentTextStyle: TextStyle(color: c.onSurface),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      dividerTheme: DividerThemeData(color: c.outlineVariant, thickness: 1),
    );
  }
}
