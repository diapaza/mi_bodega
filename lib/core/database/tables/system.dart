import 'package:drift/drift.dart';

import 'auth.dart';

/// Tiendas (una bodega por instalación típicamente; modelo multitienda futuro).
class Stores extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get name => text().withLength(min: 1, max: 120)();

  TextColumn get rucDni => text().nullable()();

  TextColumn get address => text().nullable()();

  TextColumn get phone => text().nullable()();

  /// Código ISO 4217. Default PEN.
  TextColumn get currency => text().withDefault(const Constant('PEN'))();

  BoolColumn get active => boolean().withDefault(const Constant(true))();

  DateTimeColumn get createdAt =>
      dateTime().clientDefault(() => DateTime.now())();

  DateTimeColumn get updatedAt =>
      dateTime().clientDefault(() => DateTime.now())();

}

/// Traza de auditoría de acciones sensibles.
@TableIndex(name: 'idx_audit_user', columns: {#userId})
@TableIndex(name: 'idx_audit_entity', columns: {#entityType, #entityId})
@TableIndex(name: 'idx_audit_created', columns: {#createdAt})
class AuditLogs extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get userId => integer().nullable().references(Users, #id)();

  /// create | update | delete | login | logout | backup | restore | ...
  TextColumn get action => text()();

  TextColumn get entityType => text()();

  TextColumn get entityId => text().nullable()();

  TextColumn get beforeJson => text().nullable()();

  TextColumn get afterJson => text().nullable()();

  DateTimeColumn get createdAt =>
      dateTime().clientDefault(() => DateTime.now())();

}

/// Historial local de respaldos (base para la futura sincronización con Drive).
@TableIndex(name: 'idx_backups_store', columns: {#storeId})
@TableIndex(name: 'idx_backups_created', columns: {#createdAt})
class Backups extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get storeId => integer().references(Stores, #id)();

  TextColumn get filename => text()();

  TextColumn get driveFileId => text().nullable()();

  IntColumn get size => integer().nullable()();

  /// SHA-256 del archivo de respaldo.
  TextColumn get checksum => text().nullable()();

  /// manual | automatic
  TextColumn get type => text()();

  /// created | uploaded | failed | restored
  TextColumn get status => text()();

  IntColumn get schemaVersion => integer().nullable()();

  TextColumn get appVersion => text().nullable()();

  DateTimeColumn get createdAt =>
      dateTime().clientDefault(() => DateTime.now())();

}

/// Configuración de la app como pares clave/valor.
class AppSettings extends Table {
  TextColumn get key => text()();

  TextColumn get value => text()();

  DateTimeColumn get updatedAt =>
      dateTime().clientDefault(() => DateTime.now())();

  @override
  Set<Column<Object>> get primaryKey => {key};
}
