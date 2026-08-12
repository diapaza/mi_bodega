import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

enum MbButtonVariant { primary, secondary, outlined, text, destructive }

/// Botón reutilizable de MiBodega.
class MbButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final MbButtonVariant variant;
  final bool loading;
  final bool fullWidth;
  final IconData? icon;

  const MbButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = MbButtonVariant.primary,
    this.loading = false,
    this.fullWidth = true,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final disabled = onPressed == null || loading;
    final child = loading
        ? SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: _contentColor(context, colors),
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20),
                const SizedBox(width: 8),
              ],
              Text(label),
            ],
          );

    final contentColor = _contentColor(context, colors);

    return switch (variant) {
      MbButtonVariant.primary => FilledButton(
          onPressed: disabled ? null : onPressed,
          style: FilledButton.styleFrom(
            minimumSize: fullWidth ? const Size.fromHeight(48) : null,
          ),
          child: child,
        ),
      MbButtonVariant.secondary => FilledButton.tonal(
          onPressed: disabled ? null : onPressed,
          style: FilledButton.styleFrom(
            minimumSize: fullWidth ? const Size.fromHeight(48) : null,
            backgroundColor: colors.primaryContainer,
            foregroundColor: colors.onPrimaryContainer,
          ),
          child: child,
        ),
      MbButtonVariant.outlined => OutlinedButton(
          onPressed: disabled ? null : onPressed,
          style: OutlinedButton.styleFrom(
            minimumSize: fullWidth ? const Size.fromHeight(48) : null,
            foregroundColor: contentColor,
          ),
          child: child,
        ),
      MbButtonVariant.text => TextButton(
          onPressed: disabled ? null : onPressed,
          style: TextButton.styleFrom(
            minimumSize: fullWidth ? const Size.fromHeight(48) : null,
            foregroundColor: contentColor,
          ),
          child: child,
        ),
      MbButtonVariant.destructive => FilledButton(
          onPressed: disabled ? null : onPressed,
          style: FilledButton.styleFrom(
            minimumSize: fullWidth ? const Size.fromHeight(48) : null,
            backgroundColor: colors.error,
            foregroundColor: colors.onError,
          ),
          child: child,
        ),
    };
  }

  Color _contentColor(BuildContext context, AppColors colors) {
    return switch (variant) {
      MbButtonVariant.primary => colors.onPrimary,
      MbButtonVariant.secondary => colors.onPrimaryContainer,
      MbButtonVariant.outlined => colors.primary,
      MbButtonVariant.text => colors.primary,
      MbButtonVariant.destructive => colors.onError,
    };
  }
}
