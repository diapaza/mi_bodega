import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/money/money.dart';
import '../../../catalog/domain/entities/catalog.dart';
import 'conversions_editor.dart';
import 'product_image.dart';

class ProductFormSummary extends StatelessWidget {
  final String? photoPath;
  final String name;
  final String? sku;
  final String? barcode;
  final String? description;
  final int? categoryId;
  final int? brandId;
  final int? unitId;
  final int? purchaseUnitId;
  final double unitsPerPkg;
  final Money purchasePrice;
  final Money salePrice;
  final double stockMin;
  final double? stockMax;
  final double purchasedQty;
  final bool isEditing;
  final List<Category> categories;
  final List<Brand> brands;
  final List<Unit> units;
  final List<ConversionDraft> conversions;

  const ProductFormSummary({
    super.key,
    this.photoPath,
    required this.name,
    this.sku,
    this.barcode,
    this.description,
    this.categoryId,
    this.brandId,
    this.unitId,
    this.purchaseUnitId,
    required this.unitsPerPkg,
    required this.purchasePrice,
    required this.salePrice,
    required this.stockMin,
    this.stockMax,
    required this.purchasedQty,
    required this.isEditing,
    required this.categories,
    required this.brands,
    required this.units,
    required this.conversions,
  });

  String _unitName(int? id) {
    if (id == null) return '-';
    return units.where((u) => u.id == id).map((u) => u.name).firstOrNull ?? '-';
  }

  String _unitSymbol(int? id) {
    if (id == null) return '';
    return units.where((u) => u.id == id).map((u) => u.symbol).firstOrNull ?? '';
  }

  String _categoryName(int? id) {
    if (id == null) return 'Sin categoría';
    return categories.where((c) => c.id == id).map((c) => c.name).firstOrNull ?? '-';
  }

  String _brandName(int? id) {
    if (id == null) return 'Sin marca';
    return brands.where((b) => b.id == id).map((b) => b.name).firstOrNull ?? '-';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.colors;
    final baseUnit = _unitName(unitId);
    final purchaseUnit = _unitName(purchaseUnitId);

    Widget row(String label, String value) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 140,
                child: Text(
                  label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  value,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (photoPath != null) ...[
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: ProductImage(photoPath: photoPath, width: 180, height: 120),
              ),
            ),
            const SizedBox(height: 16),
          ],
          _SectionLabel(title: 'Información básica', colors: colors, theme: theme),
          row('Nombre', name.isEmpty ? '-' : name),
          if (sku != null && sku!.isNotEmpty) row('SKU', sku!),
          if (barcode != null && barcode!.isNotEmpty) row('Código de barras', barcode!),
          if (description != null && description!.isNotEmpty)
            row('Descripción', description!),
          const SizedBox(height: 16),
          _SectionLabel(title: 'Clasificación', colors: colors, theme: theme),
          row('Categoría', _categoryName(categoryId)),
          row('Marca', _brandName(brandId)),
          row('Unidad base', '$baseUnit (${_unitSymbol(unitId)})'),
          if (purchaseUnitId != null && purchaseUnitId != unitId)
            row('Unidad de compra', '$purchaseUnit (${_unitSymbol(purchaseUnitId)})'),
          if (purchaseUnitId != null && purchaseUnitId != unitId)
            row('Ud. venta / ud. compra', '${unitsPerPkg.toInt()}'),
          const SizedBox(height: 16),
          _SectionLabel(title: 'Precios', colors: colors, theme: theme),
          row('Costo', purchasePrice.format()),
          row('Precio de venta', salePrice.format()),
          const SizedBox(height: 16),
          _SectionLabel(title: 'Stock', colors: colors, theme: theme),
          row('Stock mínimo', '${stockMin.toInt()}'),
          if (stockMax != null) row('Stock máximo', '${stockMax!.toInt()}'),
          if (!isEditing)
            row(
              'Stock inicial',
              purchasedQty > 0
                  ? '${purchasedQty.toInt()} × $unitsPerPkg = ${(purchasedQty * unitsPerPkg).toInt()} $baseUnit'
                  : '0',
            ),
          if (conversions.isNotEmpty) ...[
            const SizedBox(height: 16),
            _SectionLabel(title: 'Conversiones', colors: colors, theme: theme),
            for (final c in conversions)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colors.surfaceContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${_unitName(c.unitId)} (${_unitSymbol(c.unitId)})',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                      Text(
                        'Factor: ${c.factor.toInt()}',
                        style: theme.textTheme.bodySmall,
                      ),
                      if (c.purchasePrice != null) ...[
                        const SizedBox(width: 12),
                        Text(
                          'Compra: ${c.purchasePrice!.format()}',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                      if (c.salePrice != null) ...[
                        const SizedBox(width: 12),
                        Text(
                          'Venta: ${c.salePrice!.format()}',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String title;
  final AppColors colors;
  final ThemeData theme;

  const _SectionLabel({
    required this.title,
    required this.colors,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          color: colors.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
