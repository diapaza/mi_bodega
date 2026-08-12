import 'package:drift/drift.dart';

import 'catalog.dart';
import 'system.dart';

/// Productos del catálogo.
///
/// Los montos (`purchasePrice`, `salePrice`, `costPrice`) están en céntimos.
/// El stock NO vive aquí: su fuente de verdad es la tabla `inventory`.
@TableIndex(name: 'idx_products_store', columns: {#storeId})
@TableIndex(name: 'idx_products_category', columns: {#categoryId})
@TableIndex(name: 'idx_products_brand', columns: {#brandId})
@TableIndex(name: 'idx_products_name', columns: {#name})
@TableIndex(name: 'idx_products_active', columns: {#active})
class Products extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get storeId => integer().references(Stores, #id)();

  IntColumn get categoryId => integer().nullable().references(Categories, #id)();

  IntColumn get brandId => integer().nullable().references(Brands, #id)();

  IntColumn get baseUnitId => integer().references(Units, #id)();

  TextColumn get sku => text().nullable()();

  TextColumn get barcode => text().nullable()();

  TextColumn get name => text().withLength(min: 1, max: 120)();

  TextColumn get description => text().nullable()();

  /// Céntimos.
  IntColumn get purchasePrice => integer().withDefault(const Constant(0))();

  /// Céntimos.
  IntColumn get salePrice => integer().withDefault(const Constant(0))();

  /// Costo promedio móvil en céntimos (base unit).
  IntColumn get costPrice => integer().withDefault(const Constant(0))();

  RealColumn get stockMin => real().withDefault(const Constant(0))();

  RealColumn get stockMax => real().nullable()();

  TextColumn get photoPath => text().nullable()();

  BoolColumn get active => boolean().withDefault(const Constant(true))();

  BoolColumn get isFavorite => boolean().withDefault(const Constant(false))();

  DateTimeColumn get createdAt =>
      dateTime().clientDefault(() => DateTime.now())();

  DateTimeColumn get updatedAt =>
      dateTime().clientDefault(() => DateTime.now())();

}

/// Conversiones de unidad por producto.
///
/// `factor` = cantidad de unidades base contenidas en 1 de esta unidad
/// (p. ej. caja = 24 unidades). Permite precios de compra/venta por unidad
/// distinta a la base.
@TableIndex(
  name: 'idx_conversion_product_unit',
  columns: {#productId, #unitId},
  unique: true,
)
class ProductUnitConversions extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get productId => integer().references(Products, #id)();

  IntColumn get unitId => integer().references(Units, #id)();

  RealColumn get factor => real().withDefault(const Constant(1))();

  /// Céntimos por unidad convertida (opcional).
  IntColumn get purchasePrice => integer().nullable()();

  /// Céntimos por unidad convertida (opcional).
  IntColumn get salePrice => integer().nullable()();

  DateTimeColumn get createdAt =>
      dateTime().clientDefault(() => DateTime.now())();

  DateTimeColumn get updatedAt =>
      dateTime().clientDefault(() => DateTime.now())();

}
