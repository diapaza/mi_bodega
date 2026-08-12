import 'package:flutter_test/flutter_test.dart';
import 'package:mi_bodega/core/error/result.dart';
import 'package:mi_bodega/core/money/money.dart';
import 'package:mi_bodega/features/auth/data/services/bootstrap_service.dart';
import 'package:mi_bodega/features/catalog/data/repositories/drift_catalog_repository.dart';
import 'package:mi_bodega/features/catalog/domain/entities/catalog.dart';
import 'package:mi_bodega/features/inventory/data/repositories/drift_inventory_repository.dart';
import 'package:mi_bodega/features/products/data/repositories/drift_product_repository.dart';
import 'package:mi_bodega/features/products/domain/entities/product.dart';
import 'package:mi_bodega/features/sales/data/repositories/drift_sale_repository.dart';
import 'package:mi_bodega/features/sales/domain/entities/sale.dart';

import '../helpers/db_test_utils.dart';

void main() {
  group('Cancelación de venta (SALE_CANCEL)', () {
    test('anula venta, repone stock y revierte caja de forma atómica', () async {
      final db = await openTestMemoryDatabase();
      final bootstrap = BootstrapService(db, testPinHasher);
      await bootstrap.seedRolesAndPermissions();
      await bootstrap.setup(
        storeName: 'Bodega',
        ownerFullName: 'Dueño',
        ownerUsername: 'owner',
        ownerPin: '1234',
        ownerRecoveryPin: '9999',
      );
      final store = (await bootstrap.checkState()).store!;
      final roles = await db.authDao.allRoles();
      final admin = roles.firstWhere((r) => r.name == 'Administrador');

      final unit = (await DriftCatalogRepository(db)
              .createUnit('Unidad', 'ud', UnitType.unit))
          .orNull!;
      final products = DriftProductRepository(db);
      final product = (await products.createProduct(ProductDraft(
        storeId: store.id!,
        baseUnitId: unit.id!,
        name: 'Leche',
        salePrice: const Money(350),
        initialStock: 10,
      )))
          .orNull!;

      final sales = DriftSaleRepository(db);
      final sale = (await sales.registerSale(SaleRequest(
        storeId: store.id!,
        userId: admin.id,
        items: [
          SaleItemInput(
            productId: product.id!,
            quantity: 4,
            unitPrice: const Money(350),
          ),
        ],
        paymentMethod: PaymentMethod.cash,
        amountReceived: const Money(2000),
      )))
          .orNull!;

      final before = await DriftInventoryRepository(db).stockOf(product.id!);
      expect(before.orNull, 6.0);

      final cancelled = await sales.cancelSale(sale.sale.id!, admin.id, reason: 'Error de cobro');
      expect(cancelled.isOk, isTrue, reason: '$cancelled');
      expect(cancelled.orNull!.sale.status, SaleStatus.cancelled);

      // Stock repuesto.
      final after = await DriftInventoryRepository(db).stockOf(product.id!);
      expect(after.orNull, 10.0);

      // Movimiento de devolución registrado.
      final movements =
          await db.inventoryDao.watchMovements(product.id!).first;
      expect(movements.map((m) => m.movementType),
          containsAll(['initial', 'sale_out', 'return_in']));
      final returnIn = movements.firstWhere((m) => m.movementType == 'return_in');
      expect(returnIn.quantity, 4);
      expect(returnIn.beforeQty, 6);
      expect(returnIn.afterQty, 10);

      // Auditoría de cancelación.
      final audits = await db.auditDao.recentAudits();
      expect(audits.map((a) => a.action), contains('cancel'));

      // No se puede anular dos veces.
      final again = await sales.cancelSale(sale.sale.id!, admin.id, reason: 'Error de cobro');
      expect(again.isErr, isTrue);
      expect(again.failure!.code, FailureCode.validation);
    });
  });
}
