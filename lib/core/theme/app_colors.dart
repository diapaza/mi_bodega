import 'package:flutter/material.dart';

/// Tokens de color de MiBodega (Sistema de diseño F1).
///
/// Cada paleta define los colores semánticos y de superficie tanto para el
/// modo claro como oscuro.
class AppColors extends ThemeExtension<AppColors> {
  final Color primary;
  final Color onPrimary;
  final Color primaryContainer;
  final Color onPrimaryContainer;
  final Color secondary;
  final Color onSecondary;
  final Color secondaryContainer;
  final Color onSecondaryContainer;
  final Color tertiary;
  final Color onTertiary;
  final Color tertiaryContainer;
  final Color onTertiaryContainer;
  final Color success;
  final Color onSuccess;
  final Color successContainer;
  final Color onSuccessContainer;
  final Color warning;
  final Color onWarning;
  final Color warningContainer;
  final Color onWarningContainer;
  final Color info;
  final Color onInfo;
  final Color infoContainer;
  final Color onInfoContainer;
  final Color error;
  final Color onError;
  final Color errorContainer;
  final Color onErrorContainer;
  final Color background;
  final Color onBackground;
  final Color surface;
  final Color onSurface;
  final Color surfaceContainer;
  final Color surfaceVariant;
  final Color onSurfaceVariant;
  final Color outline;
  final Color outlineVariant;

  const AppColors({
    required this.primary,
    required this.onPrimary,
    required this.primaryContainer,
    required this.onPrimaryContainer,
    required this.secondary,
    required this.onSecondary,
    required this.secondaryContainer,
    required this.onSecondaryContainer,
    required this.tertiary,
    required this.onTertiary,
    required this.tertiaryContainer,
    required this.onTertiaryContainer,
    required this.success,
    required this.onSuccess,
    required this.successContainer,
    required this.onSuccessContainer,
    required this.warning,
    required this.onWarning,
    required this.warningContainer,
    required this.onWarningContainer,
    required this.info,
    required this.onInfo,
    required this.infoContainer,
    required this.onInfoContainer,
    required this.error,
    required this.onError,
    required this.errorContainer,
    required this.onErrorContainer,
    required this.background,
    required this.onBackground,
    required this.surface,
    required this.onSurface,
    required this.surfaceContainer,
    required this.surfaceVariant,
    required this.onSurfaceVariant,
    required this.outline,
    required this.outlineVariant,
  });

  static const light = AppColors(
    primary: Color(0xFFE65100),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFFFE0B2),
    onPrimaryContainer: Color(0xFF5D1B00),
    secondary: Color(0xFF1E3A8A),
    onSecondary: Color(0xFFFFFFFF),
    secondaryContainer: Color(0xFFDBEAFE),
    onSecondaryContainer: Color(0xFF1E3A8A),
    tertiary: Color(0xFF0D9488),
    onTertiary: Color(0xFFFFFFFF),
    tertiaryContainer: Color(0xFFCCFBF1),
    onTertiaryContainer: Color(0xFF115E59),
    success: Color(0xFF16A34A),
    onSuccess: Color(0xFFFFFFFF),
    successContainer: Color(0xFFDCFCE7),
    onSuccessContainer: Color(0xFF14532D),
    warning: Color(0xFFD97706),
    onWarning: Color(0xFFFFFFFF),
    warningContainer: Color(0xFFFEF3C7),
    onWarningContainer: Color(0xFF78350F),
    info: Color(0xFF0284C7),
    onInfo: Color(0xFFFFFFFF),
    infoContainer: Color(0xFFE0F2FE),
    onInfoContainer: Color(0xFF0C4A6E),
    error: Color(0xFFDC2626),
    onError: Color(0xFFFFFFFF),
    errorContainer: Color(0xFFFEE2E2),
    onErrorContainer: Color(0xFF7F1D1D),
    background: Color(0xFFF3F5F9),
    onBackground: Color(0xFF0F172A),
    surface: Color(0xFFFFFFFF),
    onSurface: Color(0xFF0F172A),
    surfaceContainer: Color(0xFFF1F5F9),
    surfaceVariant: Color(0xFFE2E8F0),
    onSurfaceVariant: Color(0xFF475569),
    outline: Color(0xFF94A3B8),
    outlineVariant: Color(0xFFE2E8F0),
  );

  static const dark = AppColors(
    primary: Color(0xFFFFB74D),
    onPrimary: Color(0xFF5D1B00),
    primaryContainer: Color(0xFFE65100),
    onPrimaryContainer: Color(0xFFFFE0B2),
    secondary: Color(0xFF93C5FD),
    onSecondary: Color(0xFF1E3A8A),
    secondaryContainer: Color(0xFF1E3A8A),
    onSecondaryContainer: Color(0xFFDBEAFE),
    tertiary: Color(0xFF2DD4BF),
    onTertiary: Color(0xFF0F172A),
    tertiaryContainer: Color(0xFF115E59),
    onTertiaryContainer: Color(0xFFCCFBF1),
    success: Color(0xFF4ADE80),
    onSuccess: Color(0xFF14532D),
    successContainer: Color(0xFF14532D),
    onSuccessContainer: Color(0xFFDCFCE7),
    warning: Color(0xFFFBBF24),
    onWarning: Color(0xFF78350F),
    warningContainer: Color(0xFF78350F),
    onWarningContainer: Color(0xFFFEF3C7),
    info: Color(0xFF38BDF8),
    onInfo: Color(0xFF0C4A6E),
    infoContainer: Color(0xFF0C4A6E),
    onInfoContainer: Color(0xFFE0F2FE),
    error: Color(0xFFF87171),
    onError: Color(0xFF7F1D1D),
    errorContainer: Color(0xFF7F1D1D),
    onErrorContainer: Color(0xFFFEE2E2),
    background: Color(0xFF0F172A),
    onBackground: Color(0xFFF8FAFC),
    surface: Color(0xFF1E293B),
    onSurface: Color(0xFFF8FAFC),
    surfaceContainer: Color(0xFF334155),
    surfaceVariant: Color(0xFF475569),
    onSurfaceVariant: Color(0xFFCBD5E1),
    outline: Color(0xFF64748B),
    outlineVariant: Color(0xFF334155),
  );

  @override
  AppColors copyWith({
    Color? primary,
    Color? onPrimary,
    Color? primaryContainer,
    Color? onPrimaryContainer,
    Color? secondary,
    Color? onSecondary,
    Color? secondaryContainer,
    Color? onSecondaryContainer,
    Color? tertiary,
    Color? onTertiary,
    Color? tertiaryContainer,
    Color? onTertiaryContainer,
    Color? success,
    Color? onSuccess,
    Color? successContainer,
    Color? onSuccessContainer,
    Color? warning,
    Color? onWarning,
    Color? warningContainer,
    Color? onWarningContainer,
    Color? info,
    Color? onInfo,
    Color? infoContainer,
    Color? onInfoContainer,
    Color? error,
    Color? onError,
    Color? errorContainer,
    Color? onErrorContainer,
    Color? background,
    Color? onBackground,
    Color? surface,
    Color? onSurface,
    Color? surfaceContainer,
    Color? surfaceVariant,
    Color? onSurfaceVariant,
    Color? outline,
    Color? outlineVariant,
  }) {
    return AppColors(
      primary: primary ?? this.primary,
      onPrimary: onPrimary ?? this.onPrimary,
      primaryContainer: primaryContainer ?? this.primaryContainer,
      onPrimaryContainer: onPrimaryContainer ?? this.onPrimaryContainer,
      secondary: secondary ?? this.secondary,
      onSecondary: onSecondary ?? this.onSecondary,
      secondaryContainer: secondaryContainer ?? this.secondaryContainer,
      onSecondaryContainer: onSecondaryContainer ?? this.onSecondaryContainer,
      tertiary: tertiary ?? this.tertiary,
      onTertiary: onTertiary ?? this.onTertiary,
      tertiaryContainer: tertiaryContainer ?? this.tertiaryContainer,
      onTertiaryContainer: onTertiaryContainer ?? this.onTertiaryContainer,
      success: success ?? this.success,
      onSuccess: onSuccess ?? this.onSuccess,
      successContainer: successContainer ?? this.successContainer,
      onSuccessContainer: onSuccessContainer ?? this.onSuccessContainer,
      warning: warning ?? this.warning,
      onWarning: onWarning ?? this.onWarning,
      warningContainer: warningContainer ?? this.warningContainer,
      onWarningContainer: onWarningContainer ?? this.onWarningContainer,
      info: info ?? this.info,
      onInfo: onInfo ?? this.onInfo,
      infoContainer: infoContainer ?? this.infoContainer,
      onInfoContainer: onInfoContainer ?? this.onInfoContainer,
      error: error ?? this.error,
      onError: onError ?? this.onError,
      errorContainer: errorContainer ?? this.errorContainer,
      onErrorContainer: onErrorContainer ?? this.onErrorContainer,
      background: background ?? this.background,
      onBackground: onBackground ?? this.onBackground,
      surface: surface ?? this.surface,
      onSurface: onSurface ?? this.onSurface,
      surfaceContainer: surfaceContainer ?? this.surfaceContainer,
      surfaceVariant: surfaceVariant ?? this.surfaceVariant,
      onSurfaceVariant: onSurfaceVariant ?? this.onSurfaceVariant,
      outline: outline ?? this.outline,
      outlineVariant: outlineVariant ?? this.outlineVariant,
    );
  }

  @override
  AppColors lerp(AppColors? other, double t) {
    if (other == null) return this;
    return AppColors(
      primary: Color.lerp(primary, other.primary, t)!,
      onPrimary: Color.lerp(onPrimary, other.onPrimary, t)!,
      primaryContainer: Color.lerp(primaryContainer, other.primaryContainer, t)!,
      onPrimaryContainer: Color.lerp(onPrimaryContainer, other.onPrimaryContainer, t)!,
      secondary: Color.lerp(secondary, other.secondary, t)!,
      onSecondary: Color.lerp(onSecondary, other.onSecondary, t)!,
      secondaryContainer: Color.lerp(secondaryContainer, other.secondaryContainer, t)!,
      onSecondaryContainer: Color.lerp(onSecondaryContainer, other.onSecondaryContainer, t)!,
      tertiary: Color.lerp(tertiary, other.tertiary, t)!,
      onTertiary: Color.lerp(onTertiary, other.onTertiary, t)!,
      tertiaryContainer: Color.lerp(tertiaryContainer, other.tertiaryContainer, t)!,
      onTertiaryContainer: Color.lerp(onTertiaryContainer, other.onTertiaryContainer, t)!,
      success: Color.lerp(success, other.success, t)!,
      onSuccess: Color.lerp(onSuccess, other.onSuccess, t)!,
      successContainer: Color.lerp(successContainer, other.successContainer, t)!,
      onSuccessContainer: Color.lerp(onSuccessContainer, other.onSuccessContainer, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      onWarning: Color.lerp(onWarning, other.onWarning, t)!,
      warningContainer: Color.lerp(warningContainer, other.warningContainer, t)!,
      onWarningContainer: Color.lerp(onWarningContainer, other.onWarningContainer, t)!,
      info: Color.lerp(info, other.info, t)!,
      onInfo: Color.lerp(onInfo, other.onInfo, t)!,
      infoContainer: Color.lerp(infoContainer, other.infoContainer, t)!,
      onInfoContainer: Color.lerp(onInfoContainer, other.onInfoContainer, t)!,
      error: Color.lerp(error, other.error, t)!,
      onError: Color.lerp(onError, other.onError, t)!,
      errorContainer: Color.lerp(errorContainer, other.errorContainer, t)!,
      onErrorContainer: Color.lerp(onErrorContainer, other.onErrorContainer, t)!,
      background: Color.lerp(background, other.background, t)!,
      onBackground: Color.lerp(onBackground, other.onBackground, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      onSurface: Color.lerp(onSurface, other.onSurface, t)!,
      surfaceContainer: Color.lerp(surfaceContainer, other.surfaceContainer, t)!,
      surfaceVariant: Color.lerp(surfaceVariant, other.surfaceVariant, t)!,
      onSurfaceVariant: Color.lerp(onSurfaceVariant, other.onSurfaceVariant, t)!,
      outline: Color.lerp(outline, other.outline, t)!,
      outlineVariant: Color.lerp(outlineVariant, other.outlineVariant, t)!,
    );
  }
}

extension AppColorsX on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>() ?? AppColors.light;
}
