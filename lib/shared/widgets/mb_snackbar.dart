import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:toastification/toastification.dart';
import '../../core/theme/app_colors.dart';

enum MbSnackVariant { success, error, info, warning }

/// Muestra una notificación moderna con toastification.
void showMbSnack(
  BuildContext context,
  String message, {
  MbSnackVariant variant = MbSnackVariant.info,
  String? actionLabel,
  VoidCallback? onAction,
}) {
  final colors = Theme.of(context).extension<AppColors>() ?? AppColors.light;

  final (type, icon, bg, fg) = switch (variant) {
    MbSnackVariant.success => (
        ToastificationType.success,
        LucideIcons.circle_check,
        colors.successContainer,
        colors.success
      ),
    MbSnackVariant.error => (
        ToastificationType.error,
        LucideIcons.circle_x,
        colors.errorContainer,
        colors.error
      ),
    MbSnackVariant.info => (
        ToastificationType.info,
        LucideIcons.info,
        colors.secondaryContainer,
        colors.secondary
      ),
    MbSnackVariant.warning => (
        ToastificationType.warning,
        LucideIcons.triangle_alert,
        colors.warningContainer,
        colors.warning
      ),
  };

  toastification.show(
    context: context,
    type: type,
    style: ToastificationStyle.flatColored,
    title: Text(message),
    primaryColor: fg,
    backgroundColor: bg,
    foregroundColor: colors.onSurface,
    icon: Icon(icon, color: fg),
    alignment: Alignment.topCenter,
    autoCloseDuration: const Duration(seconds: 3),
    animationDuration: const Duration(milliseconds: 300),
    borderRadius: BorderRadius.circular(12),
    closeButtonShowType: CloseButtonShowType.none,
  );
}
