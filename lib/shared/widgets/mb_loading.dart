import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Indicador de carga centrado y moderno.
class MbLoading extends StatelessWidget {
  final String? message;
  final double size;

  const MbLoading({super.key, this.message, this.size = 32});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: colors.primary,
              backgroundColor: colors.surfaceVariant,
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: 12),
            Text(
              message!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Skeleton rectangular reutilizable para contenido de carga.
class MbSkeletonBox extends StatelessWidget {
  final double? width;
  final double? height;
  final double borderRadius;

  const MbSkeletonBox({
    super.key,
    this.width,
    this.height,
    this.borderRadius = 8,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: colors.surfaceVariant,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}
