import 'package:drift/drift.dart';

import 'tables/auth.dart';
import 'tables/cash.dart';
import 'tables/catalog.dart';
import 'tables/customers.dart';
import 'tables/inventory.dart';
import 'tables/products.dart';
import 'tables/purchases.dart';
import 'tables/sales.dart';
import 'tables/shopping_list.dart';
import 'tables/system.dart';

import 'daos.dart';
import 'migrations.dart';

part 'app_database.g.dart';

/// Base de datos local de MiBodega (offline-first).
///
/// Fuente de verdad única de toda la aplicación. Todas las escrituras de
/// negocio pasan por transacciones ([transaction]) para garantizar
/// consistencia (ventas, compras, ajustes, caja).
@DriftDatabase(
  tables: [
    Stores,
    Categories,
    Brands,
    Units,
    Products,
    ProductUnitConversions,
    Inventory,
    InventoryMovements,
    Customers,
    Users,
    Roles,
    Permissions,
    RolePermissions,
    Suppliers,
    Purchases,
    PurchaseItems,
    Sales,
    SaleItems,
    Payments,
    CashRegisters,
    CashSessions,
    CashMovements,
    AuditLogs,
    Backups,
    AppSettings,
    ShoppingListItems,
  ],
  daos: [
    CatalogDao,
    ProductDao,
    InventoryDao,
    SaleDao,
    PurchaseDao,
    CashDao,
    AuthDao,
    StoreDao,
    AuditDao,
    BackupDao,
    ShoppingListDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  /// Versión actual del esquema (para comparar con `PRAGMA user_version`).
  static const currentSchemaVersion = 5;

  @override
  int get schemaVersion => currentSchemaVersion;

  @override
  MigrationStrategy get migration => buildMigrationStrategy(this);
}
