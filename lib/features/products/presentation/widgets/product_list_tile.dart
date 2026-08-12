import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/mb_badge.dart';
import '../../domain/entities/product.dart';
import 'product_image.dart';

/// Fila de producto en vista lista.
class ProductListTile extends StatelessWidget {
  final ProductStock item;
  final VoidCallback onTap;
  final VoidCallback? onFavorite;

  const ProductListTile({
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

    return Card(
      child: ListTile(
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: ProductImage(photoPath: p.photoPath, width: 48, height: 48),
        title: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          p.sku != null && p.sku!.isNotEmpty ? p.sku! : 'Sin código',
          style: theme.textTheme.bodySmall,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onFavorite != null)
              GestureDetector(
                onTap: onFavorite,
                child: Icon(
                  p.isFavorite ? Icons.star : Icons.star_border,
                  color: p.isFavorite ? colors.secondary : colors.onSurfaceVariant,
                  size: 20,
                ),
              ),
            const SizedBox(width: 8),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  p.salePrice.format(),
                  style: theme.textTheme.titleSmall?.copyWith(color: colors.primary),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (item.outOfStock)
                      const MbBadge('Agotado', tone: MbBadgeTone.error)
                    else if (item.lowStock)
                      const MbBadge('Bajo', tone: MbBadgeTone.warning)
                    else
                      Text(
                        '${item.stock.toInt()}',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: colors.onSurfaceVariant),
                      ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
