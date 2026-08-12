import 'package:drift/drift.dart';

import 'auth.dart';
import 'products.dart';
import 'catalog.dart';

/// Saldo de inventario actual por producto (fuente de verdad del stock).
class Inventory extends Table {
  IntColumn get productId => integer().references(Products, #id)();

  RealColumn get quantity => real().withDefault(const Constant(0))();

  DateTimeColumn get updatedAt =>
      dateTime().clientDefault(() => DateTime.now())();

  @override
  Set<Column<Object>> get primaryKey => {productId};
}

/// Libro mayor de inventario: registro INMUTABLE de cada movimiento.
///
/// Nada se edita ni elimina; las correcciones son movimientos nuevos.
@TableIndex(name: 'idx_movements_product', columns: {#productId})
@TableIndex(name: 'idx_movements_created', columns: {#createdAt})
@TableIndex(name: 'idx_movements_reference', columns: {#referenceType, #referenceId})
@TableIndex(name: 'idx_movements_user', columns: {#userId})
class InventoryMovements extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get productId => integer().references(Products, #id)();

  /// initial | purchase_in | sale_out | return_in | return_out
  /// | adjustment | correction | loss | manual_in | manual_out
  TextColumn get movementType => text()();

  /// Cantidad con signo en unidades base (positivo entra, negativo sale).
  RealColumn get quantity => real()();

  RealColumn get beforeQty => real().withDefault(const Constant(0))();

  RealColumn get afterQty => real().withDefault(const Constant(0))();

  IntColumn get unitId => integer().nullable().references(Units, #id)();

  /// sale | purchase | adjustment | stocktake | null
  TextColumn get referenceType => text().nullable()();

  IntColumn get referenceId => integer().nullable()();

  IntColumn get userId => integer().nullable().references(Users, #id)();

  TextColumn get note => text().nullable()();

  DateTimeColumn get createdAt =>
      dateTime().clientDefault(() => DateTime.now())();

}
