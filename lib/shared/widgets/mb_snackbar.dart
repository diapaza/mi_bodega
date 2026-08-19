import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:toastification/toastification.dart';

enum MbSnackVariant { success, error, info, warning }

/// Muestra una notificación moderna con toastification.
void showMbSnack(
  BuildContext context,
  String message, {
  MbSnackVariant variant = MbSnackVariant.info,
  String? actionLabel,
  VoidCallback? onAction,
}) {
  final (type, icon) = switch (variant) {
    MbSnackVariant.success => (ToastificationType.success, LucideIcons.circle_check),
    MbSnackVariant.error => (ToastificationType.error, LucideIcons.circle_x),
    MbSnackVariant.info => (ToastificationType.info, LucideIcons.info),
    MbSnackVariant.warning => (ToastificationType.warning, LucideIcons.triangle_alert),
  };

  toastification.show(
    context: context,
    type: type,
    style: ToastificationStyle.fillColored,
    title: Text(message),
    icon: Icon(icon, color: Colors.white),
    alignment: Alignment.topCenter,
    autoCloseDuration: const Duration(seconds: 3),
    animationDuration: const Duration(milliseconds: 300),
    borderRadius: BorderRadius.circular(10),
    closeButtonShowType: CloseButtonShowType.none,
  );
}
