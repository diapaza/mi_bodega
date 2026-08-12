import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

enum MbSnackVariant { success, error, info, warning }

/// Muestra un snackbar con estilo semántico.
void showMbSnack(
  BuildContext context,
  String message, {
  MbSnackVariant variant = MbSnackVariant.info,
  String? actionLabel,
  VoidCallback? onAction,
}) {
  final colors = context.colors;
  final bg = switch (variant) {
    MbSnackVariant.success => colors.success,
    MbSnackVariant.error => colors.error,
    MbSnackVariant.info => colors.info,
    MbSnackVariant.warning => colors.warning,
  };
  final fg = switch (variant) {
    MbSnackVariant.success => colors.onSuccess,
    MbSnackVariant.error => colors.onError,
    MbSnackVariant.info => colors.onInfo,
    MbSnackVariant.warning => colors.onWarning,
  };
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        backgroundColor: bg,
        content: Text(message, style: TextStyle(color: fg)),
        action: actionLabel != null
            ? SnackBarAction(
                label: actionLabel,
                textColor: fg,
                onPressed: onAction ?? () {},
              )
            : null,
      ),
    );
}
