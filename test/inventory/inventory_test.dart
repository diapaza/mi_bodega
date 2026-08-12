import 'package:flutter_test/flutter_test.dart';
import 'package:mi_bodega/core/database/app_database.dart'
    hide AppUser, Store, Product, Unit, Role;
import 'package:mi_bodega/core/error/result.dart';
import 'package:mi_bodega/core/money/money.dart';
import 'package:mi_bodega/features/auth/data/services/bootstrap_service.dart';
import 'package:mi_bodega/features/inventory/data/repositories/drift_inventory_repository.dart';
import 'package:mi_bodega/features/inventory/domain/entities/inventory.dart';
import 'package:mi_bodega/features/products/data/repositories/drift_product_repository.dart';
import 'package:mi_bodega/features/products/domain/entities/product.dart';
import 'package:mi_bodega/features/purchases/data/repositories/drift_purchase_repository.dart';
import 'package:mi_bodega/features/purchases/domain/entities/purchase.dart';

import '../helpers/db_test_utils.dart';

void main() {
  late AppDatabase db;
  late DriftProductRepository products;
  late DriftInventoryRepository inventory;
  late DriftPurchaseRepository purchases;
  late int storeId;
  late int userId;
  late int unitId;

  Future<int> makeProduct({
    required String name,
    required double initialStock,
    int costCents = 0,
    double? stockMax,
    double stockMin = 0,
  }) async {
    final p = (await products.createProduct(ProductDraft(
      storeId: storeId,
      baseUnitId: unitId,
      name: name,
      purchasePrice: Money(costCents),
      salePrice: Money(costCents * 2),
      stockMin: stockMin,
      stockMax: stockMax,
      initialStock: initialStock,
    )))
        .orNull!;
    return p.id!;
  }

  setUp(() async {
    db = await openTestMemoryDatabase();
    final bootstrap = BootstrapService(db, testPinHasher);
    await bootstrap.seedRolesAndPermissions();
    await bootstrap.setup(
      storeName: 'Bodega',
      ownerFullName: 'Dueño',
      ownerUsername: 'owner',
      ownerPin: '1234',
      ownerRecoveryPin: '9999',
    );
    storeId = 1;
    userId = (await db.authDao.allUsers(1)).first.id;
    unitId = (await db.catalogDao.watchActiveUnits().first).first.id;
    products = DriftProductRepository(db);
    inventory = DriftInventoryRepository(db);
    purchases = DriftPurchaseRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('Valorización y alertas', () {
    test('valor del inventario = Σ stock × costo', () async {
      await makeProduct(name: 'A', initialStock: 10, costCents: 280);
      await makeProduct(name: 'B', initialStock: 5, costCents: 100);

      final value = await inventory.inventoryValue(storeId);
      expect(value.orNull, 3300); // 10*280 + 5*100

      final watch = await inventory.watchInventoryValue(storeId).first;
      expect(watch, 3300);
    });

    test('detección de exceso de stock (stock > máx)', () async {
      await makeProduct(name: 'Exceso', initialStock: 15, stockMax: 10);
      await makeProduct(name: 'Ok', initialStock: 5, stockMax: 10);

      final excess = await inventory.watchExcessStock(storeId).first;
      expect(excess.map((e) => e.product.name), ['Exceso']);
    });

    test('stock bajo y agotado', () async {
      await makeProduct(name: 'Bajo', initialStock: 2, stockMin: 5);
      await makeProduct(name: 'Agotado', initialStock: 0, stockMin: 1);

      final low = await inventory.watchLowStock(storeId).first;
      expect(low.map((e) => e.product.name), contains('Bajo'));

      final out = await inventory.watchOutOfStock(storeId).first;
      expect(out.map((e) => e.product.name), contains('Agotado'));
    });
  });

  group('Último costo', () {
    test('null sin compras y actualizado tras comprar', () async {
      final id = await makeProduct(name: 'A', initialStock: 5);
      expect((await inventory.lastPurchaseCost(id)).orNull, isNull);

      await purchases.createPurchase(PurchaseRequest(
        storeId: storeId,
        userId: userId,
        items: [
          PurchaseItemInput(productId: id, quantity: 10, unitPrice: const Money(250)),
        ],
      ));
      expect((await inventory.lastPurchaseCost(id)).orNull!.cents, 250);
    });
  });

  group('Ajustes manuales', () {
    test('registra before/after, motivo y auditoría', () async {
      final id = await makeProduct(name: 'A', initialStock: 10);
      final result = await inventory.adjustStock(StockAdjustment(
        productId: id,
        type: MovementType.adjustment,
        quantity: 5,
        reason: 'Conteo físico',
        userId: userId,
      ));
      expect(result.isOk, isTrue);
      final m = result.orNull!;
      expect(m.beforeQty, 10);
      expect(m.afterQty, 15);
      expect(m.quantity, 5);
      expect(m.note, 'Conteo físico');

      // Merma (salida).
      final loss = await inventory.adjustStock(StockAdjustment(
        productId: id,
        type: MovementType.loss,
        quantity: -3,
        reason: 'Producto dañado',
        userId: userId,
      ));
      expect(loss.orNull!.afterQty, 12);

      // Guard: nunca stock negativo.
      final negative = await inventory.adjustStock(StockAdjustment(
        productId: id,
        type: MovementType.correction,
        quantity: -999,
        reason: 'x',
        userId: userId,
      ));
      expect(negative.isErr, isTrue);
      expect(negative.failure!.code, FailureCode.negativeStock);

      final stock = await inventory.stockOf(id);
      expect(stock.orNull, 12);

      // Auditoría.
      final audits = await db.auditDao.recentAudits();
      expect(audits.map((a) => a.action), contains('adjust'));
    });
  });

  group('Reabastecimiento (compra)', () {
    test('aumenta stock, registra movimiento, actualiza costo promedio y audita',
        () async {
      final id = await makeProduct(name: 'A', initialStock: 10, costCents: 200);

      final result = await purchases.createPurchase(PurchaseRequest(
        storeId: storeId,
        userId: userId,
        items: [
          PurchaseItemInput(productId: id, quantity: 10, unitPrice: const Money(300)),
        ],
      ));
      expect(result.isOk, isTrue);
      expect(result.orNull!.total.cents, 3000);

      // Stock 10 → 20.
      final stock = await inventory.stockOf(id);
      expect(stock.orNull, 20);

      // Movimiento purchase_in.
      final movements = await inventory.watchMovements(id).first;
      final purchaseIn =
          movements.firstWhere((m) => m.type == MovementType.purchaseIn);
      expect(purchaseIn.beforeQty, 10);
      expect(purchaseIn.afterQty, 20);
      expect(purchaseIn.referenceType, 'purchase');

      // Costo promedio: (10*200 + 10*300)/20 = 250.
      final withStock = await products.productWithStock(id);
      expect(withStock.orNull!.product.costPrice.cents, 250);

      // Auditoría.
      final audits = await db.auditDao.recentAudits();
      expect(audits.map((a) => a.action), contains('create'));
      expect(audits.map((a) => a.entityType), contains('purchase'));
    });
  });

  group('Historial', () {
    test('movimientos por producto y global con usuario y producto', () async {
      final id = await makeProduct(name: 'A', initialStock: 5);
      await inventory.adjustStock(StockAdjustment(
        productId: id,
        type: MovementType.manualIn,
        quantity: 3,
        reason: 'Devolución de cliente',
        userId: userId,
      ));

      final perProduct = await inventory.watchMovementsWithUser(id).first;
      expect(perProduct, hasLength(2)); // initial + manual_in
      expect(perProduct.first.userName, 'Dueño');
      expect(perProduct.first.movement.note, 'Devolución de cliente');

      final global = await inventory.watchMovementsGlobal(storeId).first;
      expect(global, hasLength(2));
      expect(global.first.productName, 'A');
    });

    test('etiquetas de movimiento', () {
      expect(MovementType.purchaseIn.label, 'Compra / Abastecimiento');
      expect(MovementType.saleOut.label, 'Venta');
      expect(MovementType.loss.label, 'Merma / Pérdida');
      expect(MovementType.correction.label, 'Corrección');
    });
  });
}
