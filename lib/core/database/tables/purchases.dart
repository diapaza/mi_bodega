import 'package:drift/drift.dart';

import 'auth.dart';
import 'catalog.dart';
import 'products.dart';
import 'system.dart';

/// Proveedores (soft delete con `active`).
class Suppliers extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get storeId => integer().references(Stores, #id)();

  TextColumn get name => text()();

  TextColumn get rucDni => text().nullable()();

  TextColumn get phone => text().nullable()();

  TextColumn get address => text().nullable()();

  BoolColumn get active => boolean().withDefault(const Constant(true))();

  DateTimeColumn get createdAt =>
      dateTime().clientDefault(() => DateTime.now())();

  DateTimeColumn get updatedAt =>
      dateTime().clientDefault(() => DateTime.now())();

}

/// Compras / abastecimientos.
///
/// Al completarse, incrementa inventario y actualiza el costo promedio móvil.
@TableIndex(name: 'idx_purchases_supplier', columns: {#supplierId})
@TableIndex(name: 'idx_purchases_user', columns: {#userId})
@TableIndex(name: 'idx_purchases_date', columns: {#purchaseDate})
class Purchases extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get storeId => integer().references(Stores, #id)();

  IntColumn get supplierId => integer().nullable().references(Suppliers, #id)();

  IntColumn get userId => integer().references(Users, #id)();

  IntColumn get total => integer().withDefault(const Constant(0))();

  IntColumn get discount => integer().withDefault(const Constant(0))();

  DateTimeColumn get purchaseDate =>
      dateTime().clientDefault(() => DateTime.now())();

  /// pending | completed | cancelled
  TextColumn get status => text().withDefault(const Constant('completed'))();

  TextColumn get note => text().nullable()();

  DateTimeColumn get createdAt =>
      dateTime().clientDefault(() => DateTime.now())();

  DateTimeColumn get updatedAt =>
      dateTime().clientDefault(() => DateTime.now())();

}

/// Líneas de compra.
@TableIndex(name: 'idx_purchase_items_purchase', columns: {#purchaseId})
@TableIndex(name: 'idx_purchase_items_product', columns: {#productId})
class PurchaseItems extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get purchaseId =>
      integer().references(Purchases, #id, onDelete: KeyAction.cascade)();

  IntColumn get productId => integer().references(Products, #id)();

  RealColumn get quantity => real()();

  IntColumn get unitId => integer().nullable().references(Units, #id)();

  /// Precio unitario en la unidad de compra, céntimos.
  IntColumn get unitPrice => integer().withDefault(const Constant(0))();

  /// Factor: unidades base por 1 unidad de compra.
  RealColumn get factor => real().withDefault(const Constant(1))();

  IntColumn get subtotal => integer().withDefault(const Constant(0))();

  DateTimeColumn get createdAt =>
      dateTime().clientDefault(() => DateTime.now())();

}
