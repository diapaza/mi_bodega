import 'package:mi_bodega/core/database/app_database.dart' as db;
import 'package:mi_bodega/core/database/daos.dart' as daos;
import 'package:drift/drift.dart';
import 'package:mi_bodega/core/error/abort_transaction.dart';
import 'package:mi_bodega/core/error/failures.dart';
import 'package:mi_bodega/core/error/result.dart';
import 'package:mi_bodega/core/money/money.dart';
import 'package:mi_bodega/features/inventory/domain/entities/inventory.dart';
import 'package:mi_bodega/features/purchases/domain/entities/purchase.dart';
import 'package:mi_bodega/features/purchases/domain/repositories/purchase_repository.dart';

class DriftPurchaseRepository implements PurchaseRepository {
  final db.AppDatabase database;

  DriftPurchaseRepository(this.database);

  daos.PurchaseDao get _purchaseDao => database.purchaseDao;
  daos.ProductDao get _productDao => database.productDao;
  daos.InventoryDao get _inventoryDao => database.inventoryDao;
  daos.AuditDao get _auditDao => database.auditDao;

  @override
  Stream<List<Purchase>> watchPurchases(int storeId, {int limit = 50}) {
    return _purchaseDao.watchPurchases(storeId, limit: limit).map((rows) {
      return rows.map(_mapPurchase).toList();
    });
  }

  @override
  Future<Result<Purchase?>> purchaseById(int id) async {
    try {
      final row = await _purchaseDao.purchaseById(id);
      return Ok(row == null ? null : _mapPurchase(row));
    } catch (e) {
      return Err(failureFrom(e));
    }
  }

  @override
  Future<Result<List<PurchaseItem>>> itemsForPurchase(int purchaseId) async {
    try {
      final rows = await _purchaseDao.itemsForPurchase(purchaseId);
      return Ok(rows.map(_mapItem).toList());
    } catch (e) {
      return Err(failureFrom(e));
    }
  }

  PurchaseItem _mapItem(db.PurchaseItem i) {
    return PurchaseItem(
      id: i.id,
      purchaseId: i.purchaseId,
      productId: i.productId,
      quantity: i.quantity,
      unitId: i.unitId,
      unitPrice: Money(i.unitPrice),
      factor: i.factor,
      subtotal: Money(i.subtotal),
    );
  }

  @override
  Future<Result<Purchase>> createPurchase(PurchaseRequest request) async {
    try {
      if (request.items.isEmpty) {
        return const Err(Failure(
          code: FailureCode.validation,
          message: 'La compra no tiene productos.',
        ));
      }
      final purchase = await database.transaction(() async {
        final now = DateTime.now();

        // Procesar líneas.
        final prepared = <_PreparedPurchaseItem>[];
        var total = 0;
        for (final input in request.items) {
          final product = await _productDao.productById(input.productId);
          if (product == null) {
            throw AbortTransaction(Failure(
              code: FailureCode.notFound,
              message: 'Producto #${input.productId} no encontrado.',
            ));
          }
          if (input.quantity <= 0 || input.factor <= 0) {
            throw AbortTransaction(Failure(
              code: FailureCode.validation,
              message: 'Cantidad inválida para ${product.name}.',
            ));
          }
          final itemSubtotal = Money((input.unitPrice.cents * input.quantity).round());
          total += itemSubtotal.cents;
          prepared.add(_PreparedPurchaseItem(
            input: input,
            baseQty: input.quantity * input.factor,
            subtotal: itemSubtotal,
          ));
        }
        final grandTotal = Money(total) - request.discount;

        final purchaseId = await _purchaseDao.insertPurchase(
          db.PurchasesCompanion.insert(
            storeId: request.storeId,
            supplierId: request.supplierId == null
                ? const Value.absent()
                : Value(request.supplierId),
            userId: request.userId,
            total: Value(grandTotal.cents),
            discount: Value(request.discount.cents),
            purchaseDate: Value(now),
            note: request.note == null
                ? const Value.absent()
                : Value(request.note),
          ),
        );

        for (final item in prepared) {
          await _purchaseDao.insertPurchaseItem(db.PurchaseItemsCompanion.insert(
            purchaseId: purchaseId,
            productId: item.input.productId,
            quantity: item.input.quantity,
            unitId: item.input.unitId == null
                ? const Value.absent()
                : Value(item.input.unitId),
            unitPrice: Value(item.input.unitPrice.cents),
            factor: Value(item.input.factor),
            subtotal: Value(item.subtotal.cents),
          ));

          // Stock + movimiento.
          final before = await _inventoryDao.stockOf(item.input.productId);
          final after = before + item.baseQty;
          await _inventoryDao.upsertInventory(item.input.productId, after);
          await _inventoryDao.insertMovement(db.InventoryMovementsCompanion.insert(
            productId: item.input.productId,
            movementType: MovementType.purchaseIn.dbName,
            quantity: item.baseQty,
            beforeQty: Value(before),
            afterQty: Value(after),
            unitId: item.input.unitId == null
                ? const Value.absent()
                : Value(item.input.unitId),
            referenceType: const Value('purchase'),
            referenceId: Value(purchaseId),
            userId: Value(request.userId),
          ));

          // Costo promedio móvil.
          await _updateMovingCost(item.input.productId, item);
        }

        await _auditDao.insertAudit(db.AuditLogsCompanion.insert(
          userId: Value(request.userId),
          action: 'create',
          entityType: 'purchase',
          entityId: Value('$purchaseId'),
          afterJson: Value('{"total":${grandTotal.cents}}'),
        ));

        final row = await _purchaseDao.purchaseById(purchaseId);
        return _mapPurchase(row!);
      });
      return Ok(purchase);
    } on AbortTransaction catch (e) {
      return Err(e.failure);
    } catch (e) {
      return Err(failureFrom(e));
    }
  }

  Future<void> _updateMovingCost(int productId, _PreparedPurchaseItem item) async {
    final product = await _productDao.productById(productId);
    if (product == null) return;
    final unitCostInBase = (item.input.unitPrice.cents / item.input.factor);
    final newStock = await _inventoryDao.stockOf(productId);
    final oldStock = newStock - item.baseQty;
    int newCost;
    if ((oldStock + item.baseQty) <= 0) {
      newCost = unitCostInBase.round();
    } else {
      final weighted =
          (oldStock * product.costPrice + item.baseQty * unitCostInBase) /
              (oldStock + item.baseQty);
      newCost = weighted.round();
    }
    await (database.update(database.products)..where((t) => t.id.equals(productId)))
        .write(db.ProductsCompanion(
      costPrice: Value(newCost),
      updatedAt: Value(DateTime.now()),
    ));
  }

  Purchase _mapPurchase(db.Purchase p) {
    return Purchase(
      id: p.id,
      storeId: p.storeId,
      supplierId: p.supplierId,
      userId: p.userId,
      total: Money(p.total),
      discount: Money(p.discount),
      purchaseDate: p.purchaseDate,
      status: _status(p.status),
      note: p.note,
      createdAt: p.createdAt,
      updatedAt: p.updatedAt,
    );
  }

  PurchaseStatus _status(String s) {
    return switch (s) {
      'pending' => PurchaseStatus.pending,
      'cancelled' => PurchaseStatus.cancelled,
      _ => PurchaseStatus.completed,
    };
  }
}

class _PreparedPurchaseItem {
  final PurchaseItemInput input;
  final double baseQty;
  final Money subtotal;

  const _PreparedPurchaseItem({
    required this.input,
    required this.baseQty,
    required this.subtotal,
  });
}
