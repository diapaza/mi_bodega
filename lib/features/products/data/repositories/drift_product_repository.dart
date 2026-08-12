import 'package:mi_bodega/core/database/app_database.dart' as db;
import 'package:drift/drift.dart';
import 'package:mi_bodega/core/database/daos.dart' as daos;
import 'package:mi_bodega/core/error/failures.dart';
import 'package:mi_bodega/core/error/result.dart';
import 'package:mi_bodega/core/money/money.dart';
import 'package:mi_bodega/features/inventory/domain/entities/inventory.dart';
import 'package:mi_bodega/features/products/domain/entities/product.dart';
import 'package:mi_bodega/features/products/domain/repositories/product_repository.dart';

class DriftProductRepository implements ProductRepository {
  final db.AppDatabase database;

  DriftProductRepository(this.database);

  daos.ProductDao get _productDao => database.productDao;
  daos.InventoryDao get _inventoryDao => database.inventoryDao;
  daos.AuditDao get _auditDao => database.auditDao;

  @override
  Stream<List<ProductStock>> watchProducts({
    required int storeId,
    bool onlyActive = true,
    String? search,
    int? categoryId,
    int? brandId,
    ProductSort? sort,
  }) {
    return _productDao
        .watchProducts(
          storeId: storeId,
          onlyActive: onlyActive,
          search: search,
          categoryId: categoryId,
          brandId: brandId,
          sort: sort,
        )
        .map((rows) => rows.map(_mapStockRow).toList());
  }

  @override
  Future<Result<List<ProductStock>>> searchProducts({
    required int storeId,
    required String search,
    bool onlyActive = true,
    int? categoryId,
    int? brandId,
  }) async {
    try {
      final rows = await _productDao.searchProducts(
        storeId: storeId,
        search: search,
        onlyActive: onlyActive,
        categoryId: categoryId,
        brandId: brandId,
      );
      return Ok(rows.map(_mapStockRow).toList());
    } catch (e) {
      return Err(failureFrom(e));
    }
  }

  @override
  Future<Result<ProductStock?>> productWithStock(int id) async {
    try {
      final row = await _productDao.productWithStock(id);
      return Ok(row == null ? null : _mapStockRow(row));
    } catch (e) {
      return Err(failureFrom(e));
    }
  }

  @override
  Future<Result<Product>> createProduct(
    ProductDraft draft, {
    List<ProductUnitConversion> conversions = const [],
  }) async {
    try {
      final now = DateTime.now();
      final id = await database.transaction(() async {
        final productId = await _productDao.insertProduct(
          db.ProductsCompanion.insert(
            storeId: draft.storeId,
            categoryId: _optInt(draft.categoryId),
            brandId: _optInt(draft.brandId),
            baseUnitId: draft.baseUnitId,
            sku: _optText(draft.sku),
            barcode: _optText(draft.barcode),
            name: draft.name,
            description: _optText(draft.description),
            purchasePrice: Value(draft.purchasePrice.cents),
            salePrice: Value(draft.salePrice.cents),
            costPrice: Value(draft.purchasePrice.cents),
            stockMin: Value(draft.stockMin),
            stockMax: draft.stockMax == null
                ? const Value.absent()
                : Value(draft.stockMax),
            photoPath: _optText(draft.photoPath),
          ),
        );
        await _saveConversions(productId, conversions);
        if (draft.initialStock > 0) {
          await _applyInitialStock(productId, draft.initialStock, now);
        }
        await _auditDao.insertAudit(db.AuditLogsCompanion.insert(
          action: 'create',
          entityType: 'product',
          entityId: Value('$productId'),
          afterJson: Value('{"name":"${draft.name}"}'),
        ));
        return productId;
      });
      final row = await _productDao.productById(id);
      return Ok(_mapProduct(row!));
    } catch (e) {
      return Err(failureFrom(e));
    }
  }

  @override
  Future<Result<Product>> updateProduct(
    int id,
    ProductDraft draft, {
    List<ProductUnitConversion> conversions = const [],
  }) async {
    try {
      final now = DateTime.now();
      await database.transaction(() async {
        final existing = await _productDao.productById(id);
        if (existing == null) {
          throw _NotFound();
        }
        final updated = existing.toCompanion(true).copyWith(
              categoryId: _optInt(draft.categoryId),
              brandId: _optInt(draft.brandId),
              baseUnitId: Value(draft.baseUnitId),
              sku: _optText(draft.sku),
              barcode: _optText(draft.barcode),
              name: Value(draft.name),
              description: _optText(draft.description),
              purchasePrice: Value(draft.purchasePrice.cents),
              salePrice: Value(draft.salePrice.cents),
              stockMin: Value(draft.stockMin),
              stockMax: draft.stockMax == null
                  ? const Value.absent()
                  : Value(draft.stockMax),
              photoPath: _optText(draft.photoPath),
              updatedAt: Value(now),
            );
        await _productDao.updateProduct(updated);

        if (existing.salePrice != draft.salePrice.cents ||
            existing.purchasePrice != draft.purchasePrice.cents) {
          await _auditDao.insertAudit(db.AuditLogsCompanion.insert(
            action: 'price_change',
            entityType: 'product',
            entityId: Value('$id'),
            beforeJson: Value(
              '{"purchase":${existing.purchasePrice},"sale":${existing.salePrice}}',
            ),
            afterJson: Value(
              '{"purchase":${draft.purchasePrice.cents},"sale":${draft.salePrice.cents}}',
            ),
          ));
        }

        await (database.delete(database.productUnitConversions)
              ..where(
                (t) => t.productId.equals(id),
              ))
            .go();
        await _saveConversions(id, conversions);

        await _auditDao.insertAudit(db.AuditLogsCompanion.insert(
          action: 'update',
          entityType: 'product',
          entityId: Value('$id'),
        ));
      });
      final row = await _productDao.productById(id);
      return Ok(_mapProduct(row!));
    } on _NotFound {
      return Err(const Failure(
        code: FailureCode.notFound,
        message: 'Producto no encontrado.',
      ));
    } catch (e) {
      return Err(failureFrom(e));
    }
  }

  @override
  Future<Result<void>> setActive(int id, bool active) async {
    try {
      await (database.update(database.products)
            ..where((t) => t.id.equals(id)))
          .write(db.ProductsCompanion(
        active: Value(active),
        updatedAt: Value(DateTime.now()),
      ));
      return const Ok(null);
    } catch (e) {
      return Err(failureFrom(e));
    }
  }

  @override
  Future<Result<void>> setFavorite(int id, bool favorite) async {
    try {
      await (database.update(database.products)
            ..where((t) => t.id.equals(id)))
          .write(db.ProductsCompanion(
        isFavorite: Value(favorite),
        updatedAt: Value(DateTime.now()),
      ));
      return const Ok(null);
    } catch (e) {
      return Err(failureFrom(e));
    }
  }

  @override
  Future<Result<bool>> canHardDelete(int id) async {
    try {
      return Ok(!await _hasHistory(id));
    } catch (e) {
      return Err(failureFrom(e));
    }
  }

  @override
  Future<Result<DeleteProductResult>> deleteProduct(int id) async {
    try {
      if (await _hasHistory(id)) {
        // Soft delete: preserva la trazabilidad.
        await (database.update(database.products)
              ..where((t) => t.id.equals(id)))
            .write(db.ProductsCompanion(
          active: Value(false),
          updatedAt: Value(DateTime.now()),
        ));
        await _auditDao.insertAudit(db.AuditLogsCompanion.insert(
          action: 'deactivate',
          entityType: 'product',
          entityId: Value('$id'),
          afterJson: Value('{"reason":"delete"}'),
        ));
        return Ok(DeleteProductResult.softDeactivated);
      }

      // Hard delete: sin historial, se puede eliminar físicamente.
      // Solo puede haber movimientos tipo 'initial' (sin historial real).
      await database.transaction(() async {
        await (database.delete(database.productUnitConversions)
              ..where((t) => t.productId.equals(id)))
            .go();
        await (database.delete(database.inventoryMovements)
              ..where((t) => t.productId.equals(id)))
            .go();
        await (database.delete(database.inventory)
              ..where((t) => t.productId.equals(id)))
            .go();
        await (database.delete(database.products)
              ..where((t) => t.id.equals(id)))
            .go();
        await _auditDao.insertAudit(db.AuditLogsCompanion.insert(
          action: 'delete',
          entityType: 'product',
          entityId: Value('$id'),
        ));
      });
      return Ok(DeleteProductResult.hardDeleted);
    } catch (e) {
      return Err(failureFrom(e));
    }
  }

  /// Un producto tiene historial transaccional si existen movimientos (salvo el
  /// inicial), ventas o compras.
  Future<bool> _hasHistory(int productId) async {
    final movementCount = await (database.selectOnly(database.inventoryMovements)
          ..addColumns([database.inventoryMovements.id.count()])
          ..where(database.inventoryMovements.productId.equals(productId) &
              database.inventoryMovements.movementType.isNotValue('initial')))
        .get();
    if ((movementCount.first.read(database.inventoryMovements.id.count()) ?? 0) > 0) {
      return true;
    }
    final saleCount = await (database.selectOnly(database.saleItems)
          ..addColumns([database.saleItems.id.count()])
          ..where(database.saleItems.productId.equals(productId)))
        .get();
    if ((saleCount.first.read(database.saleItems.id.count()) ?? 0) > 0) {
      return true;
    }
    final purchaseCount = await (database.selectOnly(database.purchaseItems)
          ..addColumns([database.purchaseItems.id.count()])
          ..where(database.purchaseItems.productId.equals(productId)))
        .get();
    return (purchaseCount.first.read(database.purchaseItems.id.count()) ?? 0) > 0;
  }

  @override
  Stream<List<ProductUnitConversion>> watchConversions(int productId) {
    return _productDao.watchConversions(productId).map((rows) {
      return rows.map(_mapConversion).toList();
    });
  }

  Future<void> _saveConversions(int productId, List<ProductUnitConversion> conversions) async {
    for (final c in conversions) {
      await _productDao.insertConversion(db.ProductUnitConversionsCompanion.insert(
        productId: productId,
        unitId: c.unitId,
        factor: Value(c.factor),
        purchasePrice: c.purchasePrice == null
            ? const Value.absent()
            : Value(c.purchasePrice!.cents),
        salePrice: c.salePrice == null
            ? const Value.absent()
            : Value(c.salePrice!.cents),
      ));
    }
  }

  Future<void> _applyInitialStock(int productId, double qty, DateTime now) async {
    await _inventoryDao.upsertInventory(productId, qty);
    await _inventoryDao.insertMovement(db.InventoryMovementsCompanion.insert(
      productId: productId,
      movementType: MovementType.initial.dbName,
      quantity: qty,
      beforeQty: Value(0),
      afterQty: Value(qty),
      note: Value('Stock inicial'),
    ));
  }

  ProductStock _mapStockRow(daos.ProductStockRow row) {
    return ProductStock(_mapProduct(row.product), row.stock);
  }

  Product _mapProduct(db.Product p) {
    return Product(
      id: p.id,
      storeId: p.storeId,
      categoryId: p.categoryId,
      brandId: p.brandId,
      baseUnitId: p.baseUnitId,
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
    );
  }

  ProductUnitConversion _mapConversion(db.ProductUnitConversion c) {
    return ProductUnitConversion(
      id: c.id,
      productId: c.productId,
      unitId: c.unitId,
      factor: c.factor,
      purchasePrice: c.purchasePrice == null ? null : Money(c.purchasePrice!),
      salePrice: c.salePrice == null ? null : Money(c.salePrice!),
      createdAt: c.createdAt,
      updatedAt: c.updatedAt,
    );
  }

  static Value<String?> _optText(String? value) =>
      value == null ? const Value.absent() : Value(value);

  static Value<int?> _optInt(int? value) =>
      value == null ? const Value.absent() : Value(value);
}

class _NotFound implements Exception {}
