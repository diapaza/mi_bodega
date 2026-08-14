import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/services/photo_service.dart';

/// Muestra la foto del producto o un fallback si no existe.
class ProductImage extends StatelessWidget {
  final String? photoPath;
  final double? width;
  final double? height;
  final BoxFit fit;
  final double borderRadius;

  const ProductImage({
    super.key,
    this.photoPath,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius = 8,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final iconSize = (width != null && width!.isFinite && width! > 0)
        ? (width! * 0.4).clamp(16.0, 48.0)
        : 40.0;
    final fallback = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: colors.surfaceVariant,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Icon(Icons.inventory_2_outlined,
          size: iconSize, color: colors.onSurfaceVariant),
    );
    if (photoPath == null || photoPath!.isEmpty) return fallback;

    return FutureBuilder<String>(
      future: absolutePhotoPath(photoPath),
      builder: (context, snapshot) {
        final path = snapshot.data ?? '';
        if (path.isEmpty || !File(path).existsSync()) return fallback;
        return ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: Image.file(
            File(path),
            width: width,
            height: height,
            fit: fit,
            errorBuilder: (_, _, _) => fallback,
          ),
        );
      },
    );
  }
}
