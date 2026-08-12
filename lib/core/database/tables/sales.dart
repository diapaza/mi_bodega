import 'package:drift/drift.dart';

import 'auth.dart';
import 'catalog.dart';
import 'customers.dart';
import 'products.dart';
import 'system.dart';
import 'cash.dart';

/// Ventas.
///
/// Los montos están en céntimos. `saleNumber` es el identificador comercial
/// secuencial (V-000001) buscable por el usuario.
@TableIndex(name: 'idx_sales_store', columns: {#storeId})
@TableIndex(
  name: 'idx_sales_store_number',
  columns: {#storeId, #saleNumber},
  unique: true,
)
@TableIndex(name: 'idx_sales_session', columns: {#cashSessionId})
@TableIndex(name: 'idx_sales_customer', columns: {#customerId})
@TableIndex(name: 'idx_sales_user', columns: {#userId})
@TableIndex(name: 'idx_sales_date', columns: {#saleDate})
class Sales extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get storeId => integer().references(Stores, #id)();

  TextColumn get saleNumber => text()();

  IntColumn get cashSessionId => integer().nullable().references(CashSessions, #id)();

  IntColumn get customerId => integer().nullable().references(Customers, #id)();

  IntColumn get userId => integer().references(Users, #id)();

  IntColumn get subtotal => integer().withDefault(const Constant(0))();

  IntColumn get discount => integer().withDefault(const Constant(0))();

  IntColumn get total => integer().withDefault(const Constant(0))();

  /// cash | yape | plin | card | other
  TextColumn get paymentMethod => text()();

  /// Monto entregado por el cliente (efectivo), céntimos. Null si no aplica.
  IntColumn get amountReceived => integer().nullable()();

  /// Vuelto a entregar, céntimos. Null si no aplica.
  IntColumn get changeDue => integer().nullable()();

  /// completed | cancelled
  TextColumn get status => text().withDefault(const Constant('completed'))();

  /// Motivo de anulación (obligatorio al anular una venta).
  TextColumn get cancelReason => text().nullable()();

  DateTimeColumn get saleDate => dateTime().clientDefault(() => DateTime.now())();

  TextColumn get note => text().nullable()();

  DateTimeColumn get createdAt =>
      dateTime().clientDefault(() => DateTime.now())();

  DateTimeColumn get updatedAt =>
      dateTime().clientDefault(() => DateTime.now())();

}

/// Líneas de una venta.
///
/// `unitPrice`/`unitCost` son instantáneas al momento de vender (auditables).
@TableIndex(name: 'idx_sale_items_sale', columns: {#saleId})
@TableIndex(name: 'idx_sale_items_product', columns: {#productId})
class SaleItems extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get saleId =>
      integer().references(Sales, #id, onDelete: KeyAction.cascade)();

  IntColumn get productId => integer().references(Products, #id)();

  RealColumn get quantity => real()();

  IntColumn get unitId => integer().nullable().references(Units, #id)();

  /// Precio de venta unitario en la unidad de venta, céntimos.
  IntColumn get unitPrice => integer().withDefault(const Constant(0))();

  /// Costo unitario en la unidad de venta, céntimos (snapshot).
  IntColumn get unitCost => integer().withDefault(const Constant(0))();

  /// Factor: unidades base por 1 unidad de venta.
  RealColumn get factor => real().withDefault(const Constant(1))();

  IntColumn get subtotal => integer().withDefault(const Constant(0))();

  DateTimeColumn get createdAt =>
      dateTime().clientDefault(() => DateTime.now())();

}

/// Desglose de métodos de pago por venta (permite pagos mixtos futuros).
@TableIndex(name: 'idx_payments_sale', columns: {#saleId})
class Payments extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get saleId =>
      integer().references(Sales, #id, onDelete: KeyAction.cascade)();

  /// cash | yape | plin | card | other
  TextColumn get method => text()();

  IntColumn get amount => integer()();

  TextColumn get reference => text().nullable()();

  IntColumn get userId => integer().nullable().references(Users, #id)();

  DateTimeColumn get createdAt =>
      dateTime().clientDefault(() => DateTime.now())();

}
