import 'package:drift/drift.dart';

import 'auth.dart';
import 'system.dart';

/// Cajas registradoras (una principal por defecto; permite varias a futuro).
class CashRegisters extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get storeId => integer().references(Stores, #id)();

  TextColumn get name => text()();

  BoolColumn get active => boolean().withDefault(const Constant(true))();

  DateTimeColumn get createdAt =>
      dateTime().clientDefault(() => DateTime.now())();

  DateTimeColumn get updatedAt =>
      dateTime().clientDefault(() => DateTime.now())();

}

/// Sesión de caja (apertura → cierre).
@TableIndex(name: 'idx_sessions_register', columns: {#registerId})
@TableIndex(name: 'idx_sessions_user', columns: {#userId})
@TableIndex(name: 'idx_sessions_status', columns: {#status})
class CashSessions extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get registerId => integer().references(CashRegisters, #id)();

  /// Usuario que abre la sesión.
  @ReferenceName('openedBy')
  IntColumn get userId => integer().references(Users, #id)();

  /// Céntimos.
  IntColumn get openingAmount => integer().withDefault(const Constant(0))();

  DateTimeColumn get openingDate =>
      dateTime().clientDefault(() => DateTime.now())();

  /// Efectivo esperado = apertura + entradas − salidas (céntimos).
  IntColumn get expectedAmount => integer().nullable()();

  /// Dinero contado por el responsable al cierre (céntimos).
  IntColumn get countedAmount => integer().nullable()();

  /// counted − expected (céntimos).
  IntColumn get difference => integer().nullable()();

  /// open | closed | cancelled
  TextColumn get status => text().withDefault(const Constant('open'))();

  /// Usuario que cierra la sesión.
  @ReferenceName('closedByUser')
  IntColumn get closedBy => integer().nullable().references(Users, #id)();

  DateTimeColumn get closingDate => dateTime().nullable()();

  TextColumn get note => text().nullable()();

  DateTimeColumn get createdAt =>
      dateTime().clientDefault(() => DateTime.now())();

  DateTimeColumn get updatedAt =>
      dateTime().clientDefault(() => DateTime.now())();

}

/// Movimientos físicos de efectivo de una sesión de caja.
///
/// Solo efectivo en caja: ventas en efectivo (saldo neto), ingresos y egresos.
@TableIndex(name: 'idx_cash_movements_session', columns: {#cashSessionId})
@TableIndex(name: 'idx_cash_movements_sale', columns: {#saleId})
class CashMovements extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get cashSessionId => integer().references(CashSessions, #id)();

  /// Referencia opcional a la venta que originó el movimiento.
  /// Columna simple (sin FK) para evitar ciclos entre tablas.
  IntColumn get saleId => integer().nullable()();

  /// opening | sale | cash_in | cash_out | adjustment | closing
  TextColumn get movementType => text()();

  /// Cantidad con signo en céntimos (positivo entra, negativo sale).
  IntColumn get amount => integer()();

  /// cash | yape | plin | card | other | null
  TextColumn get method => text().nullable()();

  IntColumn get userId => integer().nullable().references(Users, #id)();

  TextColumn get note => text().nullable()();

  DateTimeColumn get createdAt =>
      dateTime().clientDefault(() => DateTime.now())();

}
