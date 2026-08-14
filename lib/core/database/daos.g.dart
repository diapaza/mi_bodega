// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'daos.dart';

// ignore_for_file: type=lint
mixin _$CatalogDaoMixin on DatabaseAccessor<AppDatabase> {
  $CategoriesTable get categories => attachedDatabase.categories;
  $BrandsTable get brands => attachedDatabase.brands;
  $UnitsTable get units => attachedDatabase.units;
  CatalogDaoManager get managers => CatalogDaoManager(this);
}

class CatalogDaoManager {
  final _$CatalogDaoMixin _db;
  CatalogDaoManager(this._db);
  $$CategoriesTableTableManager get categories =>
      $$CategoriesTableTableManager(_db.attachedDatabase, _db.categories);
  $$BrandsTableTableManager get brands =>
      $$BrandsTableTableManager(_db.attachedDatabase, _db.brands);
  $$UnitsTableTableManager get units =>
      $$UnitsTableTableManager(_db.attachedDatabase, _db.units);
}

mixin _$ProductDaoMixin on DatabaseAccessor<AppDatabase> {
  $StoresTable get stores => attachedDatabase.stores;
  $CategoriesTable get categories => attachedDatabase.categories;
  $BrandsTable get brands => attachedDatabase.brands;
  $UnitsTable get units => attachedDatabase.units;
  $ProductsTable get products => attachedDatabase.products;
  $ProductUnitConversionsTable get productUnitConversions =>
      attachedDatabase.productUnitConversions;
  $InventoryTable get inventory => attachedDatabase.inventory;
  ProductDaoManager get managers => ProductDaoManager(this);
}

class ProductDaoManager {
  final _$ProductDaoMixin _db;
  ProductDaoManager(this._db);
  $$StoresTableTableManager get stores =>
      $$StoresTableTableManager(_db.attachedDatabase, _db.stores);
  $$CategoriesTableTableManager get categories =>
      $$CategoriesTableTableManager(_db.attachedDatabase, _db.categories);
  $$BrandsTableTableManager get brands =>
      $$BrandsTableTableManager(_db.attachedDatabase, _db.brands);
  $$UnitsTableTableManager get units =>
      $$UnitsTableTableManager(_db.attachedDatabase, _db.units);
  $$ProductsTableTableManager get products =>
      $$ProductsTableTableManager(_db.attachedDatabase, _db.products);
  $$ProductUnitConversionsTableTableManager get productUnitConversions =>
      $$ProductUnitConversionsTableTableManager(
        _db.attachedDatabase,
        _db.productUnitConversions,
      );
  $$InventoryTableTableManager get inventory =>
      $$InventoryTableTableManager(_db.attachedDatabase, _db.inventory);
}

mixin _$InventoryDaoMixin on DatabaseAccessor<AppDatabase> {
  $StoresTable get stores => attachedDatabase.stores;
  $CategoriesTable get categories => attachedDatabase.categories;
  $BrandsTable get brands => attachedDatabase.brands;
  $UnitsTable get units => attachedDatabase.units;
  $ProductsTable get products => attachedDatabase.products;
  $InventoryTable get inventory => attachedDatabase.inventory;
  $RolesTable get roles => attachedDatabase.roles;
  $UsersTable get users => attachedDatabase.users;
  $InventoryMovementsTable get inventoryMovements =>
      attachedDatabase.inventoryMovements;
  InventoryDaoManager get managers => InventoryDaoManager(this);
}

class InventoryDaoManager {
  final _$InventoryDaoMixin _db;
  InventoryDaoManager(this._db);
  $$StoresTableTableManager get stores =>
      $$StoresTableTableManager(_db.attachedDatabase, _db.stores);
  $$CategoriesTableTableManager get categories =>
      $$CategoriesTableTableManager(_db.attachedDatabase, _db.categories);
  $$BrandsTableTableManager get brands =>
      $$BrandsTableTableManager(_db.attachedDatabase, _db.brands);
  $$UnitsTableTableManager get units =>
      $$UnitsTableTableManager(_db.attachedDatabase, _db.units);
  $$ProductsTableTableManager get products =>
      $$ProductsTableTableManager(_db.attachedDatabase, _db.products);
  $$InventoryTableTableManager get inventory =>
      $$InventoryTableTableManager(_db.attachedDatabase, _db.inventory);
  $$RolesTableTableManager get roles =>
      $$RolesTableTableManager(_db.attachedDatabase, _db.roles);
  $$UsersTableTableManager get users =>
      $$UsersTableTableManager(_db.attachedDatabase, _db.users);
  $$InventoryMovementsTableTableManager get inventoryMovements =>
      $$InventoryMovementsTableTableManager(
        _db.attachedDatabase,
        _db.inventoryMovements,
      );
}

mixin _$SaleDaoMixin on DatabaseAccessor<AppDatabase> {
  $StoresTable get stores => attachedDatabase.stores;
  $CashRegistersTable get cashRegisters => attachedDatabase.cashRegisters;
  $RolesTable get roles => attachedDatabase.roles;
  $UsersTable get users => attachedDatabase.users;
  $CashSessionsTable get cashSessions => attachedDatabase.cashSessions;
  $CustomersTable get customers => attachedDatabase.customers;
  $SalesTable get sales => attachedDatabase.sales;
  $CategoriesTable get categories => attachedDatabase.categories;
  $BrandsTable get brands => attachedDatabase.brands;
  $UnitsTable get units => attachedDatabase.units;
  $ProductsTable get products => attachedDatabase.products;
  $SaleItemsTable get saleItems => attachedDatabase.saleItems;
  $PaymentsTable get payments => attachedDatabase.payments;
  SaleDaoManager get managers => SaleDaoManager(this);
}

class SaleDaoManager {
  final _$SaleDaoMixin _db;
  SaleDaoManager(this._db);
  $$StoresTableTableManager get stores =>
      $$StoresTableTableManager(_db.attachedDatabase, _db.stores);
  $$CashRegistersTableTableManager get cashRegisters =>
      $$CashRegistersTableTableManager(_db.attachedDatabase, _db.cashRegisters);
  $$RolesTableTableManager get roles =>
      $$RolesTableTableManager(_db.attachedDatabase, _db.roles);
  $$UsersTableTableManager get users =>
      $$UsersTableTableManager(_db.attachedDatabase, _db.users);
  $$CashSessionsTableTableManager get cashSessions =>
      $$CashSessionsTableTableManager(_db.attachedDatabase, _db.cashSessions);
  $$CustomersTableTableManager get customers =>
      $$CustomersTableTableManager(_db.attachedDatabase, _db.customers);
  $$SalesTableTableManager get sales =>
      $$SalesTableTableManager(_db.attachedDatabase, _db.sales);
  $$CategoriesTableTableManager get categories =>
      $$CategoriesTableTableManager(_db.attachedDatabase, _db.categories);
  $$BrandsTableTableManager get brands =>
      $$BrandsTableTableManager(_db.attachedDatabase, _db.brands);
  $$UnitsTableTableManager get units =>
      $$UnitsTableTableManager(_db.attachedDatabase, _db.units);
  $$ProductsTableTableManager get products =>
      $$ProductsTableTableManager(_db.attachedDatabase, _db.products);
  $$SaleItemsTableTableManager get saleItems =>
      $$SaleItemsTableTableManager(_db.attachedDatabase, _db.saleItems);
  $$PaymentsTableTableManager get payments =>
      $$PaymentsTableTableManager(_db.attachedDatabase, _db.payments);
}

mixin _$PurchaseDaoMixin on DatabaseAccessor<AppDatabase> {
  $StoresTable get stores => attachedDatabase.stores;
  $SuppliersTable get suppliers => attachedDatabase.suppliers;
  $RolesTable get roles => attachedDatabase.roles;
  $UsersTable get users => attachedDatabase.users;
  $PurchasesTable get purchases => attachedDatabase.purchases;
  $CategoriesTable get categories => attachedDatabase.categories;
  $BrandsTable get brands => attachedDatabase.brands;
  $UnitsTable get units => attachedDatabase.units;
  $ProductsTable get products => attachedDatabase.products;
  $PurchaseItemsTable get purchaseItems => attachedDatabase.purchaseItems;
  PurchaseDaoManager get managers => PurchaseDaoManager(this);
}

class PurchaseDaoManager {
  final _$PurchaseDaoMixin _db;
  PurchaseDaoManager(this._db);
  $$StoresTableTableManager get stores =>
      $$StoresTableTableManager(_db.attachedDatabase, _db.stores);
  $$SuppliersTableTableManager get suppliers =>
      $$SuppliersTableTableManager(_db.attachedDatabase, _db.suppliers);
  $$RolesTableTableManager get roles =>
      $$RolesTableTableManager(_db.attachedDatabase, _db.roles);
  $$UsersTableTableManager get users =>
      $$UsersTableTableManager(_db.attachedDatabase, _db.users);
  $$PurchasesTableTableManager get purchases =>
      $$PurchasesTableTableManager(_db.attachedDatabase, _db.purchases);
  $$CategoriesTableTableManager get categories =>
      $$CategoriesTableTableManager(_db.attachedDatabase, _db.categories);
  $$BrandsTableTableManager get brands =>
      $$BrandsTableTableManager(_db.attachedDatabase, _db.brands);
  $$UnitsTableTableManager get units =>
      $$UnitsTableTableManager(_db.attachedDatabase, _db.units);
  $$ProductsTableTableManager get products =>
      $$ProductsTableTableManager(_db.attachedDatabase, _db.products);
  $$PurchaseItemsTableTableManager get purchaseItems =>
      $$PurchaseItemsTableTableManager(_db.attachedDatabase, _db.purchaseItems);
}

mixin _$CashDaoMixin on DatabaseAccessor<AppDatabase> {
  $StoresTable get stores => attachedDatabase.stores;
  $CashRegistersTable get cashRegisters => attachedDatabase.cashRegisters;
  $RolesTable get roles => attachedDatabase.roles;
  $UsersTable get users => attachedDatabase.users;
  $CashSessionsTable get cashSessions => attachedDatabase.cashSessions;
  $CashMovementsTable get cashMovements => attachedDatabase.cashMovements;
  CashDaoManager get managers => CashDaoManager(this);
}

class CashDaoManager {
  final _$CashDaoMixin _db;
  CashDaoManager(this._db);
  $$StoresTableTableManager get stores =>
      $$StoresTableTableManager(_db.attachedDatabase, _db.stores);
  $$CashRegistersTableTableManager get cashRegisters =>
      $$CashRegistersTableTableManager(_db.attachedDatabase, _db.cashRegisters);
  $$RolesTableTableManager get roles =>
      $$RolesTableTableManager(_db.attachedDatabase, _db.roles);
  $$UsersTableTableManager get users =>
      $$UsersTableTableManager(_db.attachedDatabase, _db.users);
  $$CashSessionsTableTableManager get cashSessions =>
      $$CashSessionsTableTableManager(_db.attachedDatabase, _db.cashSessions);
  $$CashMovementsTableTableManager get cashMovements =>
      $$CashMovementsTableTableManager(_db.attachedDatabase, _db.cashMovements);
}

mixin _$AuthDaoMixin on DatabaseAccessor<AppDatabase> {
  $StoresTable get stores => attachedDatabase.stores;
  $RolesTable get roles => attachedDatabase.roles;
  $UsersTable get users => attachedDatabase.users;
  $PermissionsTable get permissions => attachedDatabase.permissions;
  $RolePermissionsTable get rolePermissions => attachedDatabase.rolePermissions;
  AuthDaoManager get managers => AuthDaoManager(this);
}

class AuthDaoManager {
  final _$AuthDaoMixin _db;
  AuthDaoManager(this._db);
  $$StoresTableTableManager get stores =>
      $$StoresTableTableManager(_db.attachedDatabase, _db.stores);
  $$RolesTableTableManager get roles =>
      $$RolesTableTableManager(_db.attachedDatabase, _db.roles);
  $$UsersTableTableManager get users =>
      $$UsersTableTableManager(_db.attachedDatabase, _db.users);
  $$PermissionsTableTableManager get permissions =>
      $$PermissionsTableTableManager(_db.attachedDatabase, _db.permissions);
  $$RolePermissionsTableTableManager get rolePermissions =>
      $$RolePermissionsTableTableManager(
        _db.attachedDatabase,
        _db.rolePermissions,
      );
}

mixin _$StoreDaoMixin on DatabaseAccessor<AppDatabase> {
  $StoresTable get stores => attachedDatabase.stores;
  $AppSettingsTable get appSettings => attachedDatabase.appSettings;
  StoreDaoManager get managers => StoreDaoManager(this);
}

class StoreDaoManager {
  final _$StoreDaoMixin _db;
  StoreDaoManager(this._db);
  $$StoresTableTableManager get stores =>
      $$StoresTableTableManager(_db.attachedDatabase, _db.stores);
  $$AppSettingsTableTableManager get appSettings =>
      $$AppSettingsTableTableManager(_db.attachedDatabase, _db.appSettings);
}

mixin _$AuditDaoMixin on DatabaseAccessor<AppDatabase> {
  $StoresTable get stores => attachedDatabase.stores;
  $RolesTable get roles => attachedDatabase.roles;
  $UsersTable get users => attachedDatabase.users;
  $AuditLogsTable get auditLogs => attachedDatabase.auditLogs;
  AuditDaoManager get managers => AuditDaoManager(this);
}

class AuditDaoManager {
  final _$AuditDaoMixin _db;
  AuditDaoManager(this._db);
  $$StoresTableTableManager get stores =>
      $$StoresTableTableManager(_db.attachedDatabase, _db.stores);
  $$RolesTableTableManager get roles =>
      $$RolesTableTableManager(_db.attachedDatabase, _db.roles);
  $$UsersTableTableManager get users =>
      $$UsersTableTableManager(_db.attachedDatabase, _db.users);
  $$AuditLogsTableTableManager get auditLogs =>
      $$AuditLogsTableTableManager(_db.attachedDatabase, _db.auditLogs);
}

mixin _$BackupDaoMixin on DatabaseAccessor<AppDatabase> {
  $StoresTable get stores => attachedDatabase.stores;
  $BackupsTable get backups => attachedDatabase.backups;
  BackupDaoManager get managers => BackupDaoManager(this);
}

class BackupDaoManager {
  final _$BackupDaoMixin _db;
  BackupDaoManager(this._db);
  $$StoresTableTableManager get stores =>
      $$StoresTableTableManager(_db.attachedDatabase, _db.stores);
  $$BackupsTableTableManager get backups =>
      $$BackupsTableTableManager(_db.attachedDatabase, _db.backups);
}

mixin _$ShoppingListDaoMixin on DatabaseAccessor<AppDatabase> {
  $StoresTable get stores => attachedDatabase.stores;
  $CategoriesTable get categories => attachedDatabase.categories;
  $BrandsTable get brands => attachedDatabase.brands;
  $UnitsTable get units => attachedDatabase.units;
  $ProductsTable get products => attachedDatabase.products;
  $ShoppingListItemsTable get shoppingListItems =>
      attachedDatabase.shoppingListItems;
  $InventoryTable get inventory => attachedDatabase.inventory;
  ShoppingListDaoManager get managers => ShoppingListDaoManager(this);
}

class ShoppingListDaoManager {
  final _$ShoppingListDaoMixin _db;
  ShoppingListDaoManager(this._db);
  $$StoresTableTableManager get stores =>
      $$StoresTableTableManager(_db.attachedDatabase, _db.stores);
  $$CategoriesTableTableManager get categories =>
      $$CategoriesTableTableManager(_db.attachedDatabase, _db.categories);
  $$BrandsTableTableManager get brands =>
      $$BrandsTableTableManager(_db.attachedDatabase, _db.brands);
  $$UnitsTableTableManager get units =>
      $$UnitsTableTableManager(_db.attachedDatabase, _db.units);
  $$ProductsTableTableManager get products =>
      $$ProductsTableTableManager(_db.attachedDatabase, _db.products);
  $$ShoppingListItemsTableTableManager get shoppingListItems =>
      $$ShoppingListItemsTableTableManager(
        _db.attachedDatabase,
        _db.shoppingListItems,
      );
  $$InventoryTableTableManager get inventory =>
      $$InventoryTableTableManager(_db.attachedDatabase, _db.inventory);
}
