import 'package:flutter_test/flutter_test.dart';
import 'package:mi_bodega/core/money/money.dart';
import 'package:mi_bodega/features/auth/data/services/bootstrap_service.dart';
import 'package:mi_bodega/features/catalog/data/repositories/drift_catalog_repository.dart';
import 'package:mi_bodega/features/catalog/domain/entities/catalog.dart';
import 'package:mi_bodega/features/inventory/data/repositories/drift_inventory_repository.dart';
import 'package:mi_bodega/features/products/data/repositories/drift_product_repository.dart';
import 'package:mi_bodega/features/products/domain/entities/product.dart';
import 'package:mi_bodega/features/purchases/data/repositories/drift_purchase_repository.dart';
import 'package:mi_bodega/features/purchases/domain/entities/purchase.dart';

import '../helpers/db_test_utils.dart';

void main() {
  group('Compras (transacción atómica)', () {
    test('incrementa stock, registra movimiento y actualiza costo promedio',
        () async {
      final db = await openTestMemoryDatabase();
      final bootstrap = BootstrapService(db, testPinHasher);
      await bootstrap.seedRolesAndPermissions();
      await bootstrap.setup(
        storeName: 'Bodega',
        ownerFullName: 'Dueño',
        ownerUsername: 'owner',
        ownerRecoveryPin: '9999',
        ownerPin: '1234',
      );
      final store = (await bootstrap.checkState()).store!;
      final roles = (await bootstrap.database.authDao.allRoles());
      final ownerRole = roles.firstWhere((r) => r.name == 'Administrador');

      final catalog = DriftCatalogRepository(db);
      final unit = await catalog
          .createUnit('Unidad', 'ud', UnitType.unit)
          .then((r) => r.orNull!);

      final products = DriftProductRepository(db);
      final inventory = DriftInventoryRepository(db);
      final product = await products
          .createProduct(ProductDraft(
            storeId: store.id!,
            baseUnitId: unit.id!,
            name: 'Leche',
            salePrice: const Money(350),
            purchasePrice: const Money(280),
            initialStock: 10,
          ))
          .then((r) => r.orNull!);

      final purchases = DriftPurchaseRepository(db);
      final result = await purchases.createPurchase(PurchaseRequest(
        storeId: store.id!,
        userId: ownerRole.id,
        items: [
          PurchaseItemInput(
            productId: product.id!,
            quantity: 10,
            unitPrice: const Money(280),
          ),
        ],
      ));

      expect(result.isOk, isTrue, reason: '$result');
      expect(result.orNull!.total.cents, 2800);

      final stock = await inventory.stockOf(product.id!);
      expect(stock.orNull, 20.0);

      final movements = await db.inventoryDao.watchMovements(product.id!).first;
      final purchaseIn = movements.firstWhere((m) => m.movementType == 'purchase_in');
      expect(purchaseIn.beforeQty, 10);
      expect(purchaseIn.afterQty, 20);
      expect(purchaseIn.referenceType, 'purchase');

      // Costo promedio: (10*280 + 10*280)/20 = 280.
      final updated = await products.productWithStock(product.id!);
      expect(updated.orNull!.product.costPrice.cents, 280);

      // Segunda compra a otro precio: (20*280 + 10*300)/30 = 286.67 -> 287.
      await purchases.createPurchase(PurchaseRequest(
        storeId: store.id!,
        userId: ownerRole.id,
        items: [
          PurchaseItemInput(
            productId: product.id!,
            quantity: 10,
            unitPrice: const Money(300),
          ),
        ],
      ));
      final updated2 = await products.productWithStock(product.id!);
      expect(updated2.orNull!.product.costPrice.cents, 287);
      expect(updated2.orNull!.stock, 30.0);
    });
  });
}
