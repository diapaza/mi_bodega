/// Producto del catálogo.
library;

import 'package:mi_bodega/core/money/money.dart';

class Product {
  final int? id;
  final int storeId;
  final int? categoryId;
  final int? brandId;
  final int baseUnitId;
  final String? sku;
  final String? barcode;
  final String name;
  final String? description;
  final Money purchasePrice;
  final Money salePrice;
  final Money costPrice;
  final double stockMin;
  final double? stockMax;
  final String? photoPath;
  final bool active;
  final bool isFavorite;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Product({
    this.id,
    required this.storeId,
    this.categoryId,
    this.brandId,
    required this.baseUnitId,
    this.sku,
    this.barcode,
    required this.name,
    this.description,
    this.purchasePrice = const Money.zero(),
    this.salePrice = const Money.zero(),
    this.costPrice = const Money.zero(),
    this.stockMin = 0,
    this.stockMax,
    this.photoPath,
    this.active = true,
    this.isFavorite = false,
    required this.createdAt,
    required this.updatedAt,
  });
}

/// Conversión de unidad por producto.
///
/// `factor` = cantidad de unidades base por 1 unidad convertida.
class ProductUnitConversion {
  final int? id;
  final int productId;
  final int unitId;
  final double factor;
  final Money? purchasePrice;
  final Money? salePrice;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ProductUnitConversion({
    this.id,
    required this.productId,
    required this.unitId,
    this.factor = 1,
    this.purchasePrice,
    this.salePrice,
    required this.createdAt,
    required this.updatedAt,
  });
}

/// Producto junto con su stock actual (join con inventory).
class ProductStock {
  final Product product;
  final double stock;

  const ProductStock(this.product, this.stock);

  bool get outOfStock => stock < 0.0001;

  bool get lowStock => stock <= product.stockMin && stock >= 0.0001;
}

/// Datos para crear o actualizar un producto.
class ProductDraft {
  final int storeId;
  final int? categoryId;
  final int? brandId;
  final int baseUnitId;
  final String? sku;
  final String? barcode;
  final String name;
  final String? description;
  final Money purchasePrice;
  final Money salePrice;
  final double stockMin;
  final double? stockMax;
  final String? photoPath;
  final double initialStock;

  const ProductDraft({
    required this.storeId,
    this.categoryId,
    this.brandId,
    required this.baseUnitId,
    this.sku,
    this.barcode,
    required this.name,
    this.description,
    this.purchasePrice = const Money.zero(),
    this.salePrice = const Money.zero(),
    this.stockMin = 0,
    this.stockMax,
    this.photoPath,
    this.initialStock = 0,
  });
}

/// Criterio de ordenamiento de la lista de productos.
enum ProductSort { nameAsc, priceAsc, priceDesc, stockAsc, stockDesc }

/// Resultado de eliminar un producto.
enum DeleteProductResult { hardDeleted, softDeactivated }
