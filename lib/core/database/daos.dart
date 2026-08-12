import 'package:drift/drift.dart';

import 'package:mi_bodega/features/products/domain/entities/product.dart'
    show ProductSort;

import 'app_database.dart';
import 'tables/auth.dart';
import 'tables/cash.dart';
import 'tables/catalog.dart';
import 'tables/inventory.dart';
import 'tables/products.dart';
import 'tables/purchases.dart';
import 'tables/sales.dart';
import 'tables/system.dart';

part 'daos.g.dart';

/// Fila compuesta: producto + stock actual (join products/inventory).
class ProductStockRow {
  final Product product;
  final double stock;

  const ProductStockRow(this.product, this.stock);

  bool get outOfStock => stock < 0.0001;

  bool get lowStock => stock <= product.stockMin && stock >= 0.0001;
}

/// Construye un query de productos con su stock (left join inventory).
JoinedSelectStatement<$ProductsTable, Product> _productStockQuery(
  DatabaseConnectionUser db,
  $ProductsTable products,
  $InventoryTable inventory,
) {
  return (db.select(products).join([
    leftOuterJoin(inventory, inventory.productId.equalsExp(products.id)),
  ])) as JoinedSelectStatement<$ProductsTable, Product>;
}

List<ProductStockRow> _mapStockRows(
  $ProductsTable products,
  $InventoryTable inventory,
  List<TypedResult> rows,
) {
  return rows
      .map((r) => ProductStockRow(
            r.readTable(products),
            r.readTableOrNull(inventory)?.quantity ?? 0,
          ))
      .toList();
}

@DriftAccessor(tables: [Categories, Brands, Units])
class CatalogDao extends DatabaseAccessor<AppDatabase> with _$CatalogDaoMixin {
  CatalogDao(super.db);

  Stream<List<Category>> watchActiveCategories() {
    return (select(categories)
          ..where((t) => t.active.equals(true))
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .watch();
  }

  Future<Category?> categoryById(int id) {
    return (select(categories)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  Future<int> insertCategory(CategoriesCompanion entry) =>
      into(categories).insert(entry);

  Future<bool> updateCategory(CategoriesCompanion entry) =>
      update(categories).replace(entry);

  Stream<List<Brand>> watchActiveBrands() {
    return (select(brands)
          ..where((t) => t.active.equals(true))
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .watch();
  }

  Future<int> insertBrand(BrandsCompanion entry) => into(brands).insert(entry);

  Future<bool> updateBrand(BrandsCompanion entry) =>
      update(brands).replace(entry);

  Stream<List<Unit>> watchActiveUnits() {
    return (select(units)
          ..where((t) => t.active.equals(true))
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .watch();
  }

  Future<Unit?> unitById(int id) {
    return (select(units)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<int> insertUnit(UnitsCompanion entry) => into(units).insert(entry);

  Future<bool> updateUnit(UnitsCompanion entry) =>
      update(units).replace(entry);
}

@DriftAccessor(tables: [Products, ProductUnitConversions, Inventory])
class ProductDao extends DatabaseAccessor<AppDatabase> with _$ProductDaoMixin {
  ProductDao(super.db);

  Stream<List<ProductStockRow>> watchProducts({
    required int storeId,
    bool onlyActive = true,
    String? search,
    int? categoryId,
    int? brandId,
    ProductSort? sort,
  }) {
    final query = _productStockQuery(db, products, inventory);
    query.where(products.storeId.equals(storeId));
    if (onlyActive) query.where(products.active.equals(true));
    if (categoryId != null) query.where(products.categoryId.equals(categoryId));
    if (brandId != null) query.where(products.brandId.equals(brandId));
    if (search != null && search.isNotEmpty) {
      _applySearch(query, search);
    }
    query.orderBy(_orderTerms(sort));
    return query.watch().map((rows) => _mapStockRows(products, inventory, rows));
  }

  Future<List<ProductStockRow>> searchProducts({
    required int storeId,
    required String search,
    bool onlyActive = true,
    int? categoryId,
    int? brandId,
  }) async {
    final query = _productStockQuery(db, products, inventory);
    query.where(products.storeId.equals(storeId));
    if (onlyActive) query.where(products.active.equals(true));
    if (categoryId != null) query.where(products.categoryId.equals(categoryId));
    if (brandId != null) query.where(products.brandId.equals(brandId));
    _applySearch(query, search);
    query.orderBy([OrderingTerm.asc(products.name)]);
    final rows = await query.get();
    return _mapStockRows(products, inventory, rows);
  }

  List<OrderingTerm> _orderTerms(ProductSort? sort) {
    return switch (sort) {
      ProductSort.priceAsc => [OrderingTerm.asc(products.salePrice)],
      ProductSort.priceDesc => [OrderingTerm.desc(products.salePrice)],
      ProductSort.stockAsc => [OrderingTerm.asc(inventory.quantity)],
      ProductSort.stockDesc => [OrderingTerm.desc(inventory.quantity)],
      _ => [OrderingTerm.asc(products.name)],
    };
  }

  Future<ProductStockRow?> productWithStock(int id) async {
    final query = _productStockQuery(db, products, inventory)
      ..where(products.id.equals(id))
      ..limit(1);
    final rows = await query.get();
    if (rows.isEmpty) return null;
    return _mapStockRows(products, inventory, rows).first;
  }

  Future<Product?> productById(int id) {
    return (select(products)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  Future<int> insertProduct(ProductsCompanion entry) =>
      into(products).insert(entry);

  Future<bool> updateProduct(ProductsCompanion entry) =>
      update(products).replace(entry);

  Future<List<ProductUnitConversion>> conversionsForProduct(int productId) {
    return (select(productUnitConversions)
          ..where((t) => t.productId.equals(productId)))
        .get();
  }

  Stream<List<ProductUnitConversion>> watchConversions(int productId) {
    return (select(productUnitConversions)
          ..where((t) => t.productId.equals(productId)))
        .watch();
  }

  Future<int> insertConversion(ProductUnitConversionsCompanion entry) =>
      into(productUnitConversions).insert(entry);

  Future<bool> updateConversion(ProductUnitConversionsCompanion entry) =>
      update(productUnitConversions).replace(entry);

  Future<int> deleteConversion(int id) {
    return (delete(productUnitConversions)..where((t) => t.id.equals(id)))
        .go();
  }

  void _applySearch(
    JoinedSelectStatement<$ProductsTable, Product> query,
    String search,
  ) {
    final q = search.trim();
    query.where(
      products.name.like('%$q%') |
          products.sku.like('%$q%') |
          products.barcode.like('%$q%'),
    );
  }
}

@DriftAccessor(tables: [Inventory, InventoryMovements, Products])
class InventoryDao extends DatabaseAccessor<AppDatabase>
    with _$InventoryDaoMixin {
  InventoryDao(super.db);

  Stream<double> watchStock(int productId) {
    final query = selectOnly(inventory)
      ..addColumns([inventory.quantity])
      ..where(inventory.productId.equals(productId));
    return query.watch().map((rows) {
      if (rows.isEmpty) return 0.0;
      return rows.first.read(inventory.quantity) ?? 0.0;
    });
  }

  Future<double> stockOf(int productId) async {
    final query = selectOnly(inventory)
      ..addColumns([inventory.quantity])
      ..where(inventory.productId.equals(productId));
    final rows = await query.get();
    if (rows.isEmpty) return 0.0;
    return rows.first.read(inventory.quantity) ?? 0.0;
  }

  Stream<List<InventoryMovement>> watchMovements(int productId,
      {int limit = 100}) {
    final query = (select(inventoryMovements)
          ..where((t) => t.productId.equals(productId))
          ..orderBy([(t) => OrderingTerm.desc(t.id)])
          ..limit(limit));
    return query.watch();
  }

  Stream<List<InventoryMovement>> watchAllMovements({int limit = 200}) {
    return (select(inventoryMovements)
          ..orderBy([(t) => OrderingTerm.desc(t.id)])
          ..limit(limit))
        .watch();
  }

  Future<int> insertMovement(InventoryMovementsCompanion entry) =>
      into(inventoryMovements).insert(entry);

  /// Crea el saldo inicial o actualiza la cantidad existente.
  Future<void> upsertInventory(int productId, double quantity) {
    return into(inventory)
        .insertOnConflictUpdate(InventoryCompanion(
          productId: Value(productId),
          quantity: Value(quantity),
          updatedAt: Value(DateTime.now()),
        ));
  }

  Stream<List<ProductStockRow>> watchLowStock(int storeId) {
    final query = select(products).join([
      leftOuterJoin(inventory, inventory.productId.equalsExp(products.id)),
    ]);
    query.where(
      products.storeId.equals(storeId) &
          products.active.equals(true) &
          products.stockMin.isBiggerThanValue(0) &
          (inventory.quantity.isNull() |
              inventory.quantity.isSmallerOrEqual(products.stockMin)),
    );
    query.orderBy([OrderingTerm.desc(products.stockMin)]);
    query.limit(100);
    return query.watch().map((rows) => _mapStockRows(products, inventory, rows));
  }

  Stream<List<ProductStockRow>> watchOutOfStock(int storeId) {
    final query = select(products).join([
      leftOuterJoin(inventory, inventory.productId.equalsExp(products.id)),
    ]);
    query.where(
      products.storeId.equals(storeId) &
          products.active.equals(true) &
          (inventory.quantity.isNull() |
              inventory.quantity.isSmallerThanValue(0.0001)),
    );
    query.orderBy([OrderingTerm.asc(products.name)]);
    query.limit(100);
    return query.watch().map((rows) => _mapStockRows(products, inventory, rows));
  }

  Stream<List<ProductStockRow>> watchExcessStock(int storeId) {
    final query = select(products).join([
      innerJoin(inventory, inventory.productId.equalsExp(products.id)),
    ]);
    query.where(
      products.storeId.equals(storeId) &
          products.active.equals(true) &
          products.stockMax.isNotNull() &
          inventory.quantity.isBiggerThan(products.stockMax),
    );
    query.orderBy([OrderingTerm.desc(products.stockMax)]);
    query.limit(100);
    return query.watch().map((rows) => _mapStockRows(products, inventory, rows));
  }
}

@DriftAccessor(tables: [Sales, SaleItems, Payments])
class SaleDao extends DatabaseAccessor<AppDatabase> with _$SaleDaoMixin {
  SaleDao(super.db);

  Stream<List<Sale>> watchSales({required int storeId, int limit = 50}) {
    return (select(sales)
          ..where((t) => t.storeId.equals(storeId))
          ..orderBy([(t) => OrderingTerm.desc(t.id)])
          ..limit(limit))
        .watch();
  }

  Stream<List<Sale>> watchSalesByDate(
    int storeId,
    DateTime from,
    DateTime to,
  ) {
    return (select(sales)
          ..where((t) =>
              t.storeId.equals(storeId) &
              t.saleDate.isBiggerOrEqualValue(from) &
              t.saleDate.isSmallerThanValue(to))
          ..orderBy([(t) => OrderingTerm.desc(t.saleDate)]))
        .watch();
  }

  Future<Sale?> saleById(int id) {
    return (select(sales)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<Sale?> saleByNumber(int storeId, String saleNumber) {
    return (select(sales)
          ..where(
              (t) => t.storeId.equals(storeId) & t.saleNumber.equals(saleNumber)))
        .getSingleOrNull();
  }

  Future<String?> lastSaleNumber(int storeId) {
    return (select(sales)
          ..where((t) => t.storeId.equals(storeId))
          ..orderBy([(t) => OrderingTerm.desc(t.id)])
          ..limit(1))
        .map((s) => s.saleNumber)
        .getSingleOrNull();
  }

  Future<List<SaleItem>> itemsForSale(int saleId) {
    return (select(saleItems)..where((t) => t.saleId.equals(saleId))).get();
  }

  Future<List<Payment>> paymentsForSale(int saleId) {
    return (select(payments)..where((t) => t.saleId.equals(saleId))).get();
  }

  Future<int> insertSale(SalesCompanion entry) => into(sales).insert(entry);

  Future<int> insertSaleItem(SaleItemsCompanion entry) =>
      into(saleItems).insert(entry);

  Future<int> insertPayment(PaymentsCompanion entry) =>
      into(payments).insert(entry);

  Future<int> updateSaleStatus(int saleId, String status) {
    return (update(sales)..where((t) => t.id.equals(saleId)))
        .write(SalesCompanion(
          status: Value(status),
          updatedAt: Value(DateTime.now()),
        ));
  }
}

@DriftAccessor(tables: [Suppliers, Purchases, PurchaseItems])
class PurchaseDao extends DatabaseAccessor<AppDatabase>
    with _$PurchaseDaoMixin {
  PurchaseDao(super.db);

  Stream<List<Supplier>> watchSuppliers(int storeId, {bool onlyActive = true}) {
    return (select(suppliers)
          ..where((t) => t.storeId.equals(storeId) &
              (onlyActive ? t.active.equals(true) : const Constant(true)))
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .watch();
  }

  Future<Supplier?> supplierById(int id) {
    return (select(suppliers)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  Future<int> insertSupplier(SuppliersCompanion entry) =>
      into(suppliers).insert(entry);

  Future<bool> updateSupplier(SuppliersCompanion entry) =>
      update(suppliers).replace(entry);

  Stream<List<Purchase>> watchPurchases(int storeId, {int limit = 50}) {
    return (select(purchases)
          ..where((t) => t.storeId.equals(storeId))
          ..orderBy([(t) => OrderingTerm.desc(t.id)])
          ..limit(limit))
        .watch();
  }

  Future<Purchase?> purchaseById(int id) {
    return (select(purchases)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  Future<List<PurchaseItem>> itemsForPurchase(int purchaseId) {
    return (select(purchaseItems)..where((t) => t.purchaseId.equals(purchaseId)))
        .get();
  }

  Future<int> insertPurchase(PurchasesCompanion entry) =>
      into(purchases).insert(entry);

  Future<int> insertPurchaseItem(PurchaseItemsCompanion entry) =>
      into(purchaseItems).insert(entry);
}

@DriftAccessor(tables: [CashRegisters, CashSessions, CashMovements])
class CashDao extends DatabaseAccessor<AppDatabase> with _$CashDaoMixin {
  CashDao(super.db);

  Future<int> insertRegister(CashRegistersCompanion entry) =>
      into(cashRegisters).insert(entry);

  Future<CashRegister?> defaultRegister() {
    return (select(cashRegisters)..orderBy([(t) => OrderingTerm.asc(t.id)]))
        .getSingleOrNull();
  }

  Future<CashSession?> openSession(int registerId) {
    return (select(cashSessions)
          ..where(
              (t) => t.registerId.equals(registerId) & t.status.equals('open')))
        .getSingleOrNull();
  }

  Future<CashSession?> sessionById(int id) {
    return (select(cashSessions)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  Stream<CashSession?> watchOpenSession(int registerId) {
    return (select(cashSessions)
          ..where(
              (t) => t.registerId.equals(registerId) & t.status.equals('open')))
        .watchSingleOrNull();
  }

  Stream<List<CashSession>> watchSessions(int registerId, {int limit = 50}) {
    return (select(cashSessions)
          ..where((t) => t.registerId.equals(registerId))
          ..orderBy([(t) => OrderingTerm.desc(t.id)])
          ..limit(limit))
        .watch();
  }

  Future<int> insertSession(CashSessionsCompanion entry) =>
      into(cashSessions).insert(entry);

  Future<int> updateSession(CashSessionsCompanion entry) =>
      update(cashSessions).write(entry);

  Future<int> insertMovement(CashMovementsCompanion entry) =>
      into(cashMovements).insert(entry);

  Future<List<CashMovement>> movementsForSession(int sessionId) {
    return (select(cashMovements)
          ..where((t) => t.cashSessionId.equals(sessionId)))
        .get();
  }

  /// Suma total de movimientos de la sesión (apertura + entradas − salidas).
  Future<int> sessionNet(int sessionId) async {
    final rows = await (selectOnly(cashMovements)
          ..addColumns([cashMovements.amount.sum()])
          ..where(cashMovements.cashSessionId.equals(sessionId)))
        .get();
    return rows.first.read(cashMovements.amount.sum()) ?? 0;
  }
}

@DriftAccessor(tables: [Users, Roles, Permissions, RolePermissions])
class AuthDao extends DatabaseAccessor<AppDatabase> with _$AuthDaoMixin {
  AuthDao(super.db);

  Future<AppUser?> userByUsername(String username) {
    return (select(users)..where((t) => t.username.equals(username)))
        .getSingleOrNull();
  }

  Future<AppUser?> userById(int id) {
    return (select(users)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Stream<List<AppUser>> watchUsers(int storeId) {
    return (select(users)
          ..where((t) => t.storeId.equals(storeId))
          ..orderBy([(t) => OrderingTerm.asc(t.fullName)]))
        .watch();
  }

  Future<List<AppUser>> allUsers(int storeId) {
    return (select(users)
          ..where((t) => t.storeId.equals(storeId))
          ..orderBy([(t) => OrderingTerm.asc(t.fullName)]))
        .get();
  }

  Future<int> insertUser(UsersCompanion entry) => into(users).insert(entry);

  Future<bool> updateUser(UsersCompanion entry) => update(users).replace(entry);

  Future<List<Role>> allRoles({bool onlyActive = true}) {
    return (select(roles)
          ..where((t) => onlyActive ? t.active.equals(true) : const Constant(true))
          ..orderBy([(t) => OrderingTerm.asc(t.id)]))
        .get();
  }

  Stream<List<Role>> watchRoles() {
    return (select(roles)..orderBy([(t) => OrderingTerm.asc(t.id)])).watch();
  }

  Future<Role?> roleById(int id) {
    return (select(roles)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<int> insertRole(RolesCompanion entry) => into(roles).insert(entry);

  Future<bool> updateRole(RolesCompanion entry) => update(roles).replace(entry);

  Future<int> deleteRole(int id) {
    return (delete(roles)..where((t) => t.id.equals(id))).go();
  }

  Future<int> countUsersWithRole(int roleId) {
    return (select(users)..where((t) => t.roleId.equals(roleId))).get().then((r) => r.length);
  }

  Future<void> clearPermissionsForRole(int roleId) {
    return (delete(rolePermissions)..where((t) => t.roleId.equals(roleId))).go();
  }

  Future<List<Permission>> allPermissions() {
    return (select(permissions)..orderBy([(t) => OrderingTerm.asc(t.module)]))
        .get();
  }

  Future<int> insertPermission(PermissionsCompanion entry) =>
      into(permissions).insert(entry);

  Future<List<Permission>> permissionsForRole(int roleId) async {
    final query = select(permissions).join([
      innerJoin(
        rolePermissions,
        rolePermissions.permissionId.equalsExp(permissions.id),
      ),
    ]);
    query.where(rolePermissions.roleId.equals(roleId));
    query.orderBy([OrderingTerm.asc(permissions.module)]);
    final rows = await query.get();
    return rows.map((r) => r.readTable(permissions)).toList();
  }

  Future<List<Permission>> permissionsForUser(int userId) async {
    final query = select(permissions).join([
      innerJoin(
        rolePermissions,
        rolePermissions.permissionId.equalsExp(permissions.id),
      ),
      innerJoin(users, users.roleId.equalsExp(rolePermissions.roleId)),
    ]);
    query.where(users.id.equals(userId));
    final rows = await query.get();
    return rows.map((r) => r.readTable(permissions)).toList();
  }

  Future<void> assignPermissionsToRole(int roleId, List<int> permissionIds) {
    return batch((b) {
      b.insertAll(rolePermissions, [
        for (final p in permissionIds)
          RolePermissionsCompanion.insert(roleId: roleId, permissionId: p),
      ]);
    });
  }
}

@DriftAccessor(tables: [Stores, AppSettings])
class StoreDao extends DatabaseAccessor<AppDatabase> with _$StoreDaoMixin {
  StoreDao(super.db);

  Future<Store?> firstStore() {
    return (select(stores)..orderBy([(t) => OrderingTerm.asc(t.id)]))
        .getSingleOrNull();
  }

  Stream<Store?> watchFirstStore() {
    return (select(stores)..orderBy([(t) => OrderingTerm.asc(t.id)]))
        .watchSingleOrNull();
  }

  Future<int> insertStore(StoresCompanion entry) => into(stores).insert(entry);

  Future<bool> updateStore(StoresCompanion entry) =>
      update(stores).replace(entry);

  Future<String?> getSetting(String key) {
    return (select(appSettings)..where((t) => t.key.equals(key)))
        .map((s) => s.value)
        .getSingleOrNull();
  }

  Stream<String?> watchSetting(String key) {
    return (select(appSettings)..where((t) => t.key.equals(key)))
        .map((s) => s.value)
        .watchSingleOrNull();
  }

  Future<void> putSetting(String key, String value) {
    return into(appSettings).insertOnConflictUpdate(AppSettingsCompanion(
      key: Value(key),
      value: Value(value),
      updatedAt: Value(DateTime.now()),
    ));
  }
}

@DriftAccessor(tables: [AuditLogs])
class AuditDao extends DatabaseAccessor<AppDatabase> with _$AuditDaoMixin {
  AuditDao(super.db);

  Future<int> insertAudit(AuditLogsCompanion entry) =>
      into(auditLogs).insert(entry);

  Stream<List<AuditLog>> watchAudits({int limit = 100}) {
    return (select(auditLogs)
          ..orderBy([(t) => OrderingTerm.desc(t.id)])
          ..limit(limit))
        .watch();
  }

  Future<List<AuditLog>> recentAudits({int limit = 100}) {
    return (select(auditLogs)
          ..orderBy([(t) => OrderingTerm.desc(t.id)])
          ..limit(limit))
        .get();
  }
}

@DriftAccessor(tables: [Backups])
class BackupDao extends DatabaseAccessor<AppDatabase> with _$BackupDaoMixin {
  BackupDao(super.db);

  Future<int> insertBackup(BackupsCompanion entry) =>
      into(backups).insert(entry);

  Future<int> updateBackupStatus(int id, String status) {
    return (update(backups)..where((t) => t.id.equals(id)))
        .write(BackupsCompanion(status: Value(status)));
  }

  Stream<List<Backup>> watchBackups({int limit = 50}) {
    return (select(backups)
          ..orderBy([(t) => OrderingTerm.desc(t.id)])
          ..limit(limit))
        .watch();
  }

  Future<List<Backup>> listBackups() {
    return (select(backups)..orderBy([(t) => OrderingTerm.desc(t.id)])).get();
  }

  Future<int> deleteBackup(int id) {
    return (delete(backups)..where((t) => t.id.equals(id))).go();
  }
}
