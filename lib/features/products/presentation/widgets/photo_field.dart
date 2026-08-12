import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/theme/app_colors.dart';
import 'product_image.dart';

/// Selector y vista previa de la foto del producto.
class PhotoField extends StatelessWidget {
  final String? photoPath;
  final Future<void> Function(ImageSource source) onPick;
  final Future<void> Function() onRemove;

  const PhotoField({
    super.key,
    required this.photoPath,
    required this.onPick,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: ProductImage(photoPath: photoPath, width: 180, height: 120),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton.icon(
              onPressed: () => onPick(ImageSource.gallery),
              icon: const Icon(Icons.photo_library_outlined, size: 18),
              label: const Text('Galería'),
            ),
            TextButton.icon(
              onPressed: () => onPick(ImageSource.camera),
              icon: const Icon(Icons.photo_camera_outlined, size: 18),
              label: const Text('Cámara'),
            ),
            if (photoPath != null)
              TextButton.icon(
                onPressed: onRemove,
                icon: Icon(Icons.delete_outline, size: 18, color: colors.error),
                label: Text('Quitar', style: TextStyle(color: colors.error)),
              ),
          ],
        ),
      ],
    );
  }
}
