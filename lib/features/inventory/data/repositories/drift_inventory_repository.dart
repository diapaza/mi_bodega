import 'package:mi_bodega/core/database/app_database.dart' as db;
import 'package:drift/drift.dart';
import 'package:mi_bodega/core/database/daos.dart' as daos;
import 'package:mi_bodega/core/error/abort_transaction.dart';
import 'package:mi_bodega/core/error/failures.dart';
import 'package:mi_bodega/core/error/result.dart';
import 'package:mi_bodega/core/money/money.dart';
import 'package:mi_bodega/features/inventory/domain/entities/inventory.dart';
import 'package:mi_bodega/features/inventory/domain/repositories/inventory_repository.dart';
import 'package:mi_bodega/features/products/domain/entities/product.dart';

class DriftInventoryRepository implements InventoryRepository {
  final db.AppDatabase database;

  DriftInventoryRepository(this.database);

  daos.InventoryDao get _inventoryDao => database.inventoryDao;
  daos.AuditDao get _auditDao => database.auditDao;

  @override
  Stream<double> watchStock(int productId) => _inventoryDao.watchStock(productId);

  @override
  Future<Result<double>> stockOf(int productId) async {
    try {
      return Ok(await _inventoryDao.stockOf(productId));
    } catch (e) {
      return Err(failureFrom(e));
    }
  }

  @override
  Stream<List<InventoryMovement>> watchMovements(int productId, {int limit = 100}) {
    return _inventoryDao.watchMovements(productId, limit: limit).map((rows) {
      return rows.map((m) => InventoryMovement(
            id: m.id,
            productId: m.productId,
            type: MovementTypeX.fromName(m.movementType),
            quantity: m.quantity,
            beforeQty: m.beforeQty,
            afterQty: m.afterQty,
            unitId: m.unitId,
            referenceType: m.referenceType,
            referenceId: m.referenceId,
            userId: m.userId,
            note: m.note,
            createdAt: m.createdAt,
          ))
          .toList();
    });
  }

  @override
  Stream<List<ProductStock>> watchLowStock(int storeId) {
    return _inventoryDao.watchLowStock(storeId).map((rows) {
      return rows.map(_mapStockRow).toList();
    });
  }

  @override
  Stream<List<ProductStock>> watchOutOfStock(int storeId) {
    return _inventoryDao.watchOutOfStock(storeId).map((rows) {
      return rows.map(_mapStockRow).toList();
    });
  }

  @override
  Stream<List<ProductStock>> watchExcessStock(int storeId) {
    return _inventoryDao.watchExcessStock(storeId).map((rows) {
      return rows.map(_mapStockRow).toList();
    });
  }

  @override
  Stream<double> watchInventoryValue(int storeId) {
    final costExpr = database.inventory.quantity *
        database.products.costPrice.cast<double>();
    final query = database.selectOnly(database.products).join([
      innerJoin(
        database.inventory,
        database.inventory.productId.equalsExp(database.products.id),
      ),
    ])
      ..where(database.products.storeId.equals(storeId))
      ..addColumns([costExpr.sum()]);
    return query.watch().map((rows) {
      if (rows.isEmpty) return 0;
      return rows.first.read(costExpr.sum()) ?? 0;
    });
  }

  @override
  Future<Result<double>> inventoryValue(int storeId) async {
    try {
      final costExpr = database.inventory.quantity *
          database.products.costPrice.cast<double>();
      final query = database.selectOnly(database.products).join([
        innerJoin(
          database.inventory,
          database.inventory.productId.equalsExp(database.products.id),
        ),
      ])
        ..where(database.products.storeId.equals(storeId))
        ..addColumns([costExpr.sum()]);
      final rows = await query.get();
      if (rows.isEmpty) return const Ok(0);
      return Ok(rows.first.read(costExpr.sum()) ?? 0);
    } catch (e) {
      return Err(failureFrom(e));
    }
  }

  @override
  Future<Result<Money?>> lastPurchaseCost(int productId) async {
    try {
      final row = await (database.select(database.purchaseItems)
            ..where((t) => t.productId.equals(productId))
            ..orderBy([(t) => OrderingTerm.desc(t.id)])
            ..limit(1))
          .getSingleOrNull();
      if (row == null) return const Ok(null);
      final costPerBase = (row.unitPrice / row.factor).round();
      return Ok(Money(costPerBase));
    } catch (e) {
      return Err(failureFrom(e));
    }
  }

  @override
  Stream<List<MovementWithUser>> watchMovementsWithUser(
    int productId, {
    int limit = 100,
  }) {
    final query = database.select(database.inventoryMovements).join([
      leftOuterJoin(
        database.users,
        database.users.id.equalsExp(database.inventoryMovements.userId),
      ),
    ]);
    query.where(database.inventoryMovements.productId.equals(productId));
    query.orderBy([OrderingTerm.desc(database.inventoryMovements.id)]);
    query.limit(limit);
    return query.watch().map((rows) {
      return rows.map(_mapWithUser).toList();
    });
  }

  @override
  Stream<List<MovementWithUser>> watchMovementsGlobal(
    int storeId, {
    int limit = 200,
  }) {
    final query = database.select(database.inventoryMovements).join([
      innerJoin(
        database.products,
        database.products.id.equalsExp(database.inventoryMovements.productId),
      ),
      leftOuterJoin(
        database.users,
        database.users.id.equalsExp(database.inventoryMovements.userId),
      ),
    ]);
    query.where(database.products.storeId.equals(storeId));
    query.orderBy([OrderingTerm.desc(database.inventoryMovements.id)]);
    query.limit(limit);
    return query.watch().map((rows) {
      return rows.map((r) {
        final product = r.readTable(database.products);
        final base = _mapMovement(r.readTable(database.inventoryMovements));
        final user = r.readTableOrNull(database.users);
        return MovementWithUser(base, user?.fullName, productName: product.name);
      }).toList();
    });
  }

  MovementWithUser _mapWithUser(TypedResult r) {
    final movement = _mapMovement(r.readTable(database.inventoryMovements));
    final user = r.readTableOrNull(database.users);
    return MovementWithUser(movement, user?.fullName);
  }

  InventoryMovement _mapMovement(db.InventoryMovement m) {
    return InventoryMovement(
      id: m.id,
      productId: m.productId,
      type: MovementTypeX.fromName(m.movementType),
      quantity: m.quantity,
      beforeQty: m.beforeQty,
      afterQty: m.afterQty,
      unitId: m.unitId,
      referenceType: m.referenceType,
      referenceId: m.referenceId,
      userId: m.userId,
      note: m.note,
      createdAt: m.createdAt,
    );
  }

  @override
  Future<Result<InventoryMovement>> adjustStock(StockAdjustment adjustment) async {
    try {
      final movement = await database.transaction(() async {
        final before = await _inventoryDao.stockOf(adjustment.productId);
        final delta = adjustment.quantity;
        final after = before + delta;
        if (after < 0) {
          throw const AbortTransaction(
            Failure(
              code: FailureCode.negativeStock,
              message: 'El stock no puede quedar negativo.',
            ),
          );
        }
        final id = await _inventoryDao.insertMovement(
          db.InventoryMovementsCompanion.insert(
            productId: adjustment.productId,
            movementType: adjustment.type.dbName,
            quantity: delta,
            beforeQty: Value(before),
            afterQty: Value(after),
            userId: adjustment.userId == null
                ? const Value.absent()
                : Value(adjustment.userId),
            note: adjustment.reason == null
                ? const Value.absent()
                : Value(adjustment.reason),
          ),
        );
        await _inventoryDao.upsertInventory(adjustment.productId, after);
        await _auditDao.insertAudit(db.AuditLogsCompanion.insert(
          userId: adjustment.userId == null
              ? const Value.absent()
              : Value(adjustment.userId),
          action: 'adjust',
          entityType: 'inventory',
          entityId: Value('${adjustment.productId}'),
          afterJson: Value('{"before":$before,"after":$after}'),
        ));
        return InventoryMovement(
          id: id,
          productId: adjustment.productId,
          type: adjustment.type,
          quantity: delta,
          beforeQty: before,
          afterQty: after,
          userId: adjustment.userId,
          note: adjustment.reason,
          createdAt: DateTime.now(),
        );
      });
      return Ok(movement);
    } on AbortTransaction catch (e) {
      return Err(e.failure);
    } catch (e) {
      return Err(failureFrom(e));
    }
  }

  ProductStock _mapStockRow(daos.ProductStockRow row) {
    final p = row.product;
    return ProductStock(
      Product(
        id: p.id,
        storeId: p.storeId,
        categoryId: p.categoryId,
        brandId: p.brandId,
        baseUnitId: p.baseUnitId,
        purchaseUnitId: p.purchaseUnitId,
        saleUnitsPerPurchaseUnit: p.saleUnitsPerPurchaseUnit,
        sku: p.sku,
        barcode: p.barcode,
        name: p.name,
        description: p.description,
        purchasePrice: Money(p.purchasePrice),
        salePrice: Money(p.salePrice),
        costPrice: Money(p.costPrice),
        stockMin: p.stockMin,
        stockMax: p.stockMax,
        photoPath: p.photoPath,
        active: p.active,
        isFavorite: p.isFavorite,
        createdAt: p.createdAt,
        updatedAt: p.updatedAt,
      ),
      row.stock,
    );
  }
}
