import 'package:mi_bodega/core/database/app_database.dart' as db;
import 'package:mi_bodega/core/database/daos.dart' as daos;
import 'package:drift/drift.dart';
import 'package:mi_bodega/core/error/abort_transaction.dart';
import 'package:mi_bodega/core/error/failures.dart';
import 'package:mi_bodega/core/error/result.dart';
import 'package:mi_bodega/core/ids/sale_number_generator.dart';
import 'package:mi_bodega/core/money/money.dart';
import 'package:mi_bodega/core/utils/formatters.dart';
import 'package:mi_bodega/features/cash/domain/entities/cash.dart';
import 'package:mi_bodega/features/inventory/domain/entities/inventory.dart';
import 'package:mi_bodega/features/products/domain/entities/product.dart';
import 'package:mi_bodega/features/sales/domain/entities/sale.dart';
import 'package:mi_bodega/features/sales/domain/repositories/sale_repository.dart';

class DriftSaleRepository implements SaleRepository {
  final db.AppDatabase database;

  DriftSaleRepository(this.database);

  static const _saleNumberGenerator = SaleNumberGenerator();

  daos.SaleDao get _saleDao => database.saleDao;
  daos.ProductDao get _productDao => database.productDao;
  daos.InventoryDao get _inventoryDao => database.inventoryDao;
  daos.CashDao get _cashDao => database.cashDao;
  daos.AuditDao get _auditDao => database.auditDao;

  @override
  Stream<List<Sale>> watchSales({required int storeId, int limit = 50}) {
    return _saleDao.watchSales(storeId: storeId, limit: limit).map((rows) {
      return rows.map(_mapSale).toList();
    });
  }

  @override
  Stream<List<Sale>> watchSalesByDate(int storeId, DateTime from, DateTime to) {
    return _saleDao.watchSalesByDate(storeId, from, to).map((rows) {
      return rows.map(_mapSale).toList();
    });
  }

  @override
  Future<Result<SaleDetail?>> saleByNumber(int storeId, String saleNumber) async {
    try {
      final sale = await _saleDao.saleByNumber(storeId, saleNumber);
      if (sale == null) return const Ok(null);
      return Ok(await _buildDetail(sale));
    } catch (e) {
      return Err(failureFrom(e));
    }
  }

  @override
  Future<Result<SaleDetail?>> saleById(int id) async {
    try {
      final sale = await _saleDao.saleById(id);
      if (sale == null) return const Ok(null);
      return Ok(await _buildDetail(sale));
    } catch (e) {
      return Err(failureFrom(e));
    }
  }

  @override
  Future<Result<SaleDetail>> registerSale(SaleRequest request) async {
    try {
      if (request.items.isEmpty) {
        return const Err(Failure(
          code: FailureCode.validation,
          message: 'La venta no tiene productos.',
        ));
      }
      if (request.discount.isNegative) {
        return const Err(Failure(
          code: FailureCode.validation,
          message: 'El descuento no puede ser negativo.',
        ));
      }
      final detail = await database.transaction(() async {
        final now = DateTime.now();

        // 1. Número de venta secuencial dentro de la transacción.
        final lastNumber = await _saleDao.lastSaleNumber(request.storeId);
        final saleNumber = _saleNumberGenerator.next(lastNumber);

        // 2. Procesar líneas y validar stock.
        final prepared = <_PreparedItem>[];
        var subtotal = 0;
        for (final input in request.items) {
          final product = await _productDao.productById(input.productId);
          if (product == null) {
            throw AbortTransaction(Failure(
              code: FailureCode.notFound,
              message: 'Producto #${input.productId} no encontrado.',
            ));
          }
          if (input.quantity <= 0) {
            throw AbortTransaction(Failure(
              code: FailureCode.validation,
              message: 'Cantidad inválida para ${product.name}.',
            ));
          }
          final stock = await _inventoryDao.stockOf(input.productId);
          final baseQty = input.quantity * input.factor;
          if (baseQty > stock + 0.0001) {
            throw AbortTransaction(Failure(
              code: FailureCode.insufficientStock,
              message: 'Stock insuficiente de ${product.name} '
                  '(disponible: ${fmtQty(stock)}).',
            ));
          }
          final unitPrice = input.unitPrice.cents;
          final itemSubtotal = Money((unitPrice * input.quantity).round());
          subtotal += itemSubtotal.cents;
          prepared.add(_PreparedItem(
            input: input,
            baseQty: baseQty,
            unitCost: Money((product.costPrice * input.factor).round()),
            subtotal: itemSubtotal,
          ));
        }

        final total = Money(subtotal) - request.discount;

        // 3. Efectivo: validar monto recibido y calcular vuelto.
        Money? amountReceived;
        Money? changeDue;
        if (request.paymentMethod == PaymentMethod.cash) {
          final received = request.amountReceived ?? Money.zero();
          if (received < total) {
            throw AbortTransaction(Failure(
              code: FailureCode.validation,
              message: 'El monto recibido es menor al total '
                  '(faltan ${(total - received).format()}).',
            ));
          }
          amountReceived = received;
          changeDue = received - total;
        }

        // 4. Crear venta.
        final saleId = await _saleDao.insertSale(db.SalesCompanion.insert(
          storeId: request.storeId,
          saleNumber: saleNumber,
          cashSessionId: request.cashSessionId == null
              ? const Value.absent()
              : Value(request.cashSessionId),
          customerId: request.customerId == null
              ? const Value.absent()
              : Value(request.customerId),
          userId: request.userId,
          subtotal: Value(subtotal),
          discount: Value(request.discount.cents),
          total: Value(total.cents),
          paymentMethod: request.paymentMethod.dbName,
          amountReceived: amountReceived == null
              ? const Value.absent()
              : Value(amountReceived.cents),
          changeDue: changeDue == null
              ? const Value.absent()
              : Value(changeDue.cents),
          saleDate: Value(now),
          note: request.note == null
              ? const Value.absent()
              : Value(request.note),
        ));

        // 5. Líneas + descontar stock + movimientos.
        for (final item in prepared) {
          await _saleDao.insertSaleItem(db.SaleItemsCompanion.insert(
            saleId: saleId,
            productId: item.input.productId,
            quantity: item.input.quantity,
            unitId: item.input.unitId == null
                ? const Value.absent()
                : Value(item.input.unitId),
            unitPrice: Value(item.input.unitPrice.cents),
            unitCost: Value(item.unitCost.cents),
            factor: Value(item.input.factor),
            subtotal: Value(item.subtotal.cents),
          ));
          final before = await _inventoryDao.stockOf(item.input.productId);
          final after = before - item.baseQty;
          await _inventoryDao.upsertInventory(item.input.productId, after);
          await _inventoryDao.insertMovement(db.InventoryMovementsCompanion.insert(
            productId: item.input.productId,
            movementType: MovementType.saleOut.dbName,
            quantity: -item.baseQty,
            beforeQty: Value(before),
            afterQty: Value(after),
            unitId: item.input.unitId == null
                ? const Value.absent()
                : Value(item.input.unitId),
            referenceType: const Value('sale'),
            referenceId: Value(saleId),
            userId: Value(request.userId),
          ));
        }

        // 6. Pago (un método por venta por ahora).
        await _saleDao.insertPayment(db.PaymentsCompanion.insert(
          saleId: saleId,
          method: request.paymentMethod.dbName,
          amount: total.cents,
          userId: Value(request.userId),
        ));

        // 7. Caja: registrar movimiento de efectivo si aplica.
        if (request.paymentMethod == PaymentMethod.cash &&
            request.cashSessionId != null) {
          await _cashDao.insertMovement(db.CashMovementsCompanion.insert(
            cashSessionId: request.cashSessionId!,
            saleId: Value(saleId),
            movementType: 'sale',
            amount: total.cents,
            method: Value('cash'),
            userId: Value(request.userId),
          ));
        }

        // 8. Auditoría.
        await _auditDao.insertAudit(db.AuditLogsCompanion.insert(
          userId: Value(request.userId),
          action: 'create',
          entityType: 'sale',
          entityId: Value(saleNumber),
          afterJson: Value('{"total":${total.cents}}'),
        ));

        final sale = await _saleDao.saleById(saleId);
        return await _buildDetail(sale!);
      });
      return Ok(detail);
    } on AbortTransaction catch (e) {
      return Err(e.failure);
    } catch (e) {
      return Err(failureFrom(e));
    }
  }

  @override
  Future<Result<SaleDetail>> cancelSale(
    int saleId,
    int userId, {
    required String reason,
  }) async {
    if (reason.trim().isEmpty) {
      return const Err(Failure(
        code: FailureCode.validation,
        message: 'El motivo de anulación es obligatorio.',
      ));
    }
    try {
      final detail = await database.transaction(() async {
        final sale = await _saleDao.saleById(saleId);
        if (sale == null) {
          throw AbortTransaction(const Failure(
            code: FailureCode.notFound,
            message: 'Venta no encontrada.',
          ));
        }
        if (sale.status != 'completed') {
          throw AbortTransaction(Failure(
            code: FailureCode.validation,
            message: 'La venta ${sale.saleNumber} ya no está activa.',
          ));
        }
        final items = await _saleDao.itemsForSale(saleId);

        // Reponer stock + movimientos.
        for (final item in items) {
          final baseQty = item.quantity * item.factor;
          final before = await _inventoryDao.stockOf(item.productId);
          final after = before + baseQty;
          await _inventoryDao.upsertInventory(item.productId, after);
          await _inventoryDao.insertMovement(db.InventoryMovementsCompanion.insert(
            productId: item.productId,
            movementType: MovementType.returnIn.dbName,
            quantity: baseQty,
            beforeQty: Value(before),
            afterQty: Value(after),
            unitId: item.unitId == null ? const Value.absent() : Value(item.unitId),
            referenceType: const Value('sale'),
            referenceId: Value(saleId),
            userId: Value(userId),
            note: Value('Anulación de venta ${sale.saleNumber}: $reason'),
          ));
        }

        // Revertir efectivo en caja si la venta fue en efectivo.
        if (sale.paymentMethod == 'cash' && sale.cashSessionId != null) {
          await _cashDao.insertMovement(db.CashMovementsCompanion.insert(
            cashSessionId: sale.cashSessionId!,
            saleId: Value(saleId),
            movementType: CashMovementType.adjustment.dbName,
            amount: -sale.total,
            method: Value('cash'),
            userId: Value(userId),
            note: Value('Anulación de venta ${sale.saleNumber}: $reason'),
          ));
        }

        final now = DateTime.now();
        await (database.update(database.sales)..where((t) => t.id.equals(saleId)))
            .write(db.SalesCompanion(
          status: const Value('cancelled'),
          cancelReason: Value(reason.trim()),
          updatedAt: Value(now),
        ));
        await _auditDao.insertAudit(db.AuditLogsCompanion.insert(
          userId: Value(userId),
          action: 'cancel',
          entityType: 'sale',
          entityId: Value(sale.saleNumber),
          afterJson: Value('{"total":${sale.total},"reason":"$reason"}'),
        ));

        final updated = await _saleDao.saleById(saleId);
        return await _buildDetail(updated!);
      });
      return Ok(detail);
    } on AbortTransaction catch (e) {
      return Err(e.failure);
    } catch (e) {
      return Err(failureFrom(e));
    }
  }

  @override
  Stream<List<Sale>> watchSalesFiltered({
    required int storeId,
    DateTime? from,
    DateTime? to,
    int? userId,
    String? method,
    String? search,
  }) {
    final hasSearch = search != null && search.isNotEmpty;
    final query = database.select(database.sales).join([
      if (hasSearch)
        leftOuterJoin(
          database.customers,
          database.customers.id.equalsExp(database.sales.customerId),
        ),
    ]);
    final conditions = <Expression<bool>>[database.sales.storeId.equals(storeId)];
    if (from != null) {
      conditions.add(database.sales.saleDate.isBiggerOrEqualValue(from));
    }
    if (to != null) {
      conditions.add(database.sales.saleDate.isSmallerThanValue(to));
    }
    if (userId != null) {
      conditions.add(database.sales.userId.equals(userId));
    }
    if (method != null) {
      conditions.add(database.sales.paymentMethod.equals(method));
    }
    if (hasSearch) {
      conditions.add(
        database.sales.saleNumber.like('%$search%') |
            database.customers.name.like('%$search%') |
            database.customers.dni.like('%$search%'),
      );
    }
    query.where(conditions.reduce((a, b) => a & b));
    query.orderBy([OrderingTerm.desc(database.sales.id)]);
    return query.watch().map((rows) {
      return rows.map((r) => _mapSale(r.readTable(database.sales))).toList();
    });
  }

  @override
  Future<Result<List<TopSoldProduct>>> topSoldProducts(
    int storeId, {
    int limit = 8,
  }) async {
    try {
      final query = database.select(database.saleItems).join([
        innerJoin(
          database.products,
          database.products.id.equalsExp(database.saleItems.productId),
        ),
        leftOuterJoin(
          database.inventory,
          database.inventory.productId.equalsExp(database.products.id),
        ),
      ]);
      query.where(
        database.products.storeId.equals(storeId) &
            database.products.active.equals(true),
      );
      query.groupBy([database.saleItems.productId]);
      query.addColumns([database.saleItems.quantity.sum()]);
      query.orderBy([OrderingTerm.desc(database.saleItems.quantity.sum())]);
      query.limit(limit);

      final rows = await query.get();
      return Ok(rows.map((r) {
        final p = r.readTable(database.products);
        final inv = r.readTableOrNull(database.inventory);
        return TopSoldProduct(
          ProductStock(
            _mapProduct(p),
            inv?.quantity ?? 0,
          ),
          r.read(database.saleItems.quantity.sum()) ?? 0,
        );
      }).toList());
    } catch (e) {
      return Err(failureFrom(e));
    }
  }

  Product _mapProduct(db.Product p) {
    return Product(
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
    );
  }

  Future<SaleDetail> _buildDetail(db.Sale sale) async {
    final items = await _saleDao.itemsForSale(sale.id);
    final payments = await _saleDao.paymentsForSale(sale.id);
    return SaleDetail(
      _mapSale(sale),
      items.map(_mapItem).toList(),
      payments.map(_mapPayment).toList(),
    );
  }

  Sale _mapSale(db.Sale s) {
    return Sale(
      id: s.id,
      storeId: s.storeId,
      saleNumber: s.saleNumber,
      cashSessionId: s.cashSessionId,
      customerId: s.customerId,
      userId: s.userId,
      subtotal: Money(s.subtotal),
      discount: Money(s.discount),
      total: Money(s.total),
      paymentMethod: PaymentMethodX.fromName(s.paymentMethod),
      amountReceived: s.amountReceived == null ? null : Money(s.amountReceived!),
      changeDue: s.changeDue == null ? null : Money(s.changeDue!),
      status: s.status == 'cancelled' ? SaleStatus.cancelled : SaleStatus.completed,
      cancelReason: s.cancelReason,
      saleDate: s.saleDate,
      note: s.note,
      createdAt: s.createdAt,
      updatedAt: s.updatedAt,
    );
  }

  SaleItem _mapItem(db.SaleItem i) {
    return SaleItem(
      id: i.id,
      saleId: i.saleId,
      productId: i.productId,
      quantity: i.quantity,
      unitId: i.unitId,
      unitPrice: Money(i.unitPrice),
      unitCost: Money(i.unitCost),
      factor: i.factor,
      subtotal: Money(i.subtotal),
    );
  }

  Payment _mapPayment(db.Payment p) {
    return Payment(
      id: p.id,
      saleId: p.saleId,
      method: PaymentMethodX.fromName(p.method),
      amount: Money(p.amount),
      reference: p.reference,
      userId: p.userId,
    );
  }
}

class _PreparedItem {
  final SaleItemInput input;
  final double baseQty;
  final Money unitCost;
  final Money subtotal;

  const _PreparedItem({
    required this.input,
    required this.baseQty,
    required this.unitCost,
    required this.subtotal,
  });
}
