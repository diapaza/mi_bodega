import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/mb_badge.dart';
import '../../domain/entities/product.dart';
import 'product_image.dart';

/// Tarjeta de producto en vista grid.
class ProductCard extends StatelessWidget {
  final ProductStock item;
  final VoidCallback onTap;
  final VoidCallback? onFavorite;

  const ProductCard({
    super.key,
    required this.item,
    required this.onTap,
    this.onFavorite,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.colors;
    final p = item.product;

    final stockBadge = item.outOfStock
        ? const MbBadge('Agotado', tone: MbBadgeTone.error)
        : item.lowStock
            ? MbBadge('Stock bajo', tone: MbBadgeTone.warning)
            : null;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ProductImage(photoPath: p.photoPath, width: double.infinity, height: 96),
                if (p.isFavorite)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Icon(Icons.star, color: colors.secondary, size: 20),
                  ),
                if (onFavorite != null)
                  Positioned(
                    top: 6,
                    left: 6,
                    child: GestureDetector(
                      onTap: onFavorite,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: colors.surface.withValues(alpha: 0.8),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          p.isFavorite ? Icons.star : Icons.star_border,
                          color: p.isFavorite ? colors.secondary : colors.onSurfaceVariant,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    p.salePrice.format(),
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: colors.primary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      if (stockBadge != null) ...[stockBadge, const Spacer()],
                      Text(
                        _stockLabel(item.stock),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _stockLabel(double stock) {
    return stock == stock.roundToDouble()
        ? 'Stock: ${stock.toInt()}'
        : 'Stock: ${stock.toStringAsFixed(2)}';
  }
}
