import 'package:drift/drift.dart';

import 'system.dart';

/// Clientes (datos opcionales de venta: DNI/nombre dejables en blanco).
@TableIndex(name: 'idx_customers_store', columns: {#storeId})
@TableIndex(name: 'idx_customers_dni', columns: {#dni})
class Customers extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get storeId => integer().references(Stores, #id)();

  TextColumn get name => text()();

  TextColumn get dni => text().nullable()();

  TextColumn get phone => text().nullable()();

  TextColumn get email => text().nullable()();

  DateTimeColumn get createdAt =>
      dateTime().clientDefault(() => DateTime.now())();

  DateTimeColumn get updatedAt =>
      dateTime().clientDefault(() => DateTime.now())();

}
