import 'package:drift/drift.dart';

import 'system.dart';

/// Usuarios del sistema (personal de la tienda).
@DataClassName('AppUser')
@TableIndex(name: 'idx_users_store', columns: {#storeId})
@TableIndex(name: 'idx_users_role', columns: {#roleId})
class Users extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get storeId => integer().references(Stores, #id)();

  TextColumn get fullName => text().withLength(min: 1, max: 120)();

  TextColumn get username => text().unique()();

  /// Hash PBKDF2 del PIN (nunca en claro).
  TextColumn get pinHash => text()();

  /// Hash PBKDF2 del PIN de recuperación (opcional, propietario).
  TextColumn get recoveryPinHash => text().nullable()();

  IntColumn get roleId => integer().references(Roles, #id)();

  BoolColumn get active => boolean().withDefault(const Constant(true))();

  BoolColumn get isOwner => boolean().withDefault(const Constant(false))();

  DateTimeColumn get createdAt =>
      dateTime().clientDefault(() => DateTime.now())();

  DateTimeColumn get updatedAt =>
      dateTime().clientDefault(() => DateTime.now())();

}

/// Roles de usuario (soft delete con `active`).
class Roles extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get name => text().withLength(min: 1, max: 60)();

  TextColumn get description => text().nullable()();

  /// Los roles de sistema no se pueden editar ni eliminar.
  BoolColumn get isSystem => boolean().withDefault(const Constant(false))();

  BoolColumn get active => boolean().withDefault(const Constant(true))();

  DateTimeColumn get createdAt =>
      dateTime().clientDefault(() => DateTime.now())();

  DateTimeColumn get updatedAt =>
      dateTime().clientDefault(() => DateTime.now())();

}

/// Catálogo de permisos (seed estático, no mutable por el usuario).
class Permissions extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// p. ej. `sales.create`
  TextColumn get code => text().unique()();

  TextColumn get name => text()();

  /// Módulo al que pertenece (pos, products, cash...).
  TextColumn get module => text()();

  TextColumn get description => text().nullable()();

}

/// Asociación rol → permiso (PK compuesta).
class RolePermissions extends Table {
  IntColumn get roleId => integer().references(Roles, #id)();

  IntColumn get permissionId => integer().references(Permissions, #id)();

  DateTimeColumn get createdAt =>
      dateTime().clientDefault(() => DateTime.now())();

  @override
  Set<Column<Object>> get primaryKey => {roleId, permissionId};
}
