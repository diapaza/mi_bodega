import 'package:flutter_test/flutter_test.dart';
import 'package:mi_bodega/core/database/app_database.dart' hide AppUser, Store;
import 'package:mi_bodega/core/error/result.dart';
import 'package:mi_bodega/core/money/money.dart';
import 'package:mi_bodega/features/auth/data/repositories/drift_auth_repository.dart';
import 'package:mi_bodega/features/auth/data/services/bootstrap_service.dart';
import 'package:mi_bodega/features/auth/domain/entities/auth.dart';
import 'package:mi_bodega/features/cash/data/repositories/drift_cash_repository.dart';
import 'package:mi_bodega/features/catalog/data/repositories/drift_catalog_repository.dart';
import 'package:mi_bodega/features/catalog/domain/entities/catalog.dart';
import 'package:mi_bodega/features/inventory/data/repositories/drift_inventory_repository.dart';
import 'package:mi_bodega/features/products/data/repositories/drift_product_repository.dart';
import 'package:mi_bodega/features/products/domain/entities/product.dart';
import 'package:mi_bodega/features/sales/data/repositories/drift_sale_repository.dart';
import 'package:mi_bodega/features/sales/domain/entities/sale.dart';
import 'package:mi_bodega/features/store/data/repositories/drift_store_repository.dart';
import 'package:mi_bodega/features/store/domain/entities/store.dart';

import '../helpers/db_test_utils.dart';

class _Env {
  final AppDatabase db;
  final BootstrapService bootstrap;
  final DriftSaleRepository sales;
  final DriftProductRepository products;
  final DriftInventoryRepository inventory;
  final DriftCashRepository cash;
  final DriftAuthRepository auth;
  final DriftCatalogRepository catalog;
  final DriftStoreRepository storeRepo;

  _Env(this.db, this.bootstrap, this.sales, this.products, this.inventory,
      this.cash, this.auth, this.catalog, this.storeRepo);

  Store? store;
  AppUser? owner;
  AppUser? vendedor;
  int unitId = 0;
}

Future<_Env> _setup() async {
  final db = await openTestMemoryDatabase();
  final bootstrap = BootstrapService(db, testPinHasher);
  final env = _Env(
    db,
    bootstrap,
    DriftSaleRepository(db),
    DriftProductRepository(db),
    DriftInventoryRepository(db),
    DriftCashRepository(db),
    DriftAuthRepository(db, testPinHasher),
    DriftCatalogRepository(db),
    DriftStoreRepository(db),
  );
  await bootstrap.seedRolesAndPermissions();
  await bootstrap.setup(
    storeName: 'Bodega Test',
    ownerFullName: 'Dueña',
    ownerUsername: 'owner',
        ownerRecoveryPin: '9999',
    ownerPin: '1234',
  );
  env.store = (await bootstrap.checkState()).store;

  final unit = await env.catalog
      .createUnit('Unidad', 'ud', UnitType.unit)
      .then((r) => r.orNull!);
  env.unitId = unit.id!;

  final roles = await env.auth.listRoles().then((r) => r.orNull!);
  final vendedorRole = roles.firstWhere((r) => r.name == 'Vendedor');
  env.vendedor = await env.auth
      .createUser(UserDraft(
        storeId: env.store!.id!,
        fullName: 'Vendedor 1',
        username: 'v1',
        pin: '1234',
        roleId: vendedorRole.id!,
      ))
      .then((r) => r.orNull!);
  env.owner = await env.auth
      .authenticate('owner', '1234')
      .then((r) => r.orNull!.user);

  return env;
}

void main() {
  group('Ventas (transacción atómica)', () {
    test('registra venta, descuenta stock, numero secuencial y vuelto',
        () async {
      final env = await _setup();
      final register = await env.db.cashDao.defaultRegister();
      final session = await env.cash.openSession(
        registerId: register!.id,
        userId: env.vendedor!.id!,
        openingAmount: const Money(1000), // S/ 10.00
      );
      final sessionId = session.orNull!.id!;

      final product = await env.products
          .createProduct(
            ProductDraft(
              storeId: env.store!.id!,
              baseUnitId: env.unitId,
              name: 'Leche',
              sku: 'L01',
              salePrice: Money(350),
              purchasePrice: Money(280),
              initialStock: 100,
            ),
          )
          .then((r) => r.orNull!);

      final result = await env.sales.registerSale(SaleRequest(
        storeId: env.store!.id!,
        userId: env.vendedor!.id!,
        cashSessionId: sessionId,
        items: [
          SaleItemInput(
            productId: product.id!,
            quantity: 2,
            unitPrice: const Money(350),
          ),
        ],
        paymentMethod: PaymentMethod.cash,
        amountReceived: const Money(1000),
      ));

      expect(result.isOk, isTrue, reason: '$result');
      final detail = result.orNull!;
      expect(detail.sale.saleNumber, 'V-000001');
      expect(detail.sale.total.cents, 700);
      expect(detail.sale.changeDue!.cents, 300);
      expect(detail.sale.subtotal.cents, 700);
      expect(detail.items.single.productId, product.id);
      expect(detail.payments.single.method, PaymentMethod.cash);
      expect(detail.payments.single.amount.cents, 700);

      // Stock descontado y movimiento registrado.
      final stock = await env.inventory.stockOf(product.id!);
      expect(stock.orNull, 98.0);
      final movements = await env.db.inventoryDao.watchMovements(product.id!).first;
      expect(movements, hasLength(2)); // initial + sale_out
      final saleOut = movements.first;
      expect(saleOut.movementType, 'sale_out');
      expect(saleOut.quantity, -2);
      expect(saleOut.beforeQty, 100);
      expect(saleOut.afterQty, 98);

      // Número secuencial en la segunda venta.
      final second = await env.sales.registerSale(SaleRequest(
        storeId: env.store!.id!,
        userId: env.vendedor!.id!,
        cashSessionId: sessionId,
        items: [
          SaleItemInput(
            productId: product.id!,
            quantity: 1,
            unitPrice: const Money(350),
          ),
        ],
        paymentMethod: PaymentMethod.cash,
        amountReceived: const Money(350),
      ));
      expect(second.orNull!.sale.saleNumber, 'V-000002');

      // La venta se encuentra por número.
      final found = await env.sales.saleByNumber(env.store!.id!, 'V-000002');
      expect(found.orNull!.sale.total.cents, 350);

      // Cierre de caja: esperado = apertura + venta1 (700) + venta2 (350).
      final closed = await env.cash.closeSession(
        sessionId: sessionId,
        closedBy: env.owner!.id!,
        countedAmount: Money(2050), // 1000 + 700 + 350
        authorizeDifference: false,
      );
      expect(closed.isOk, isTrue, reason: '$closed');
      expect(closed.orNull!.expectedAmount!.cents, 2050);
      expect(closed.orNull!.difference!.cents, 0);
      expect(closed.orNull!.isOpen, isFalse);
    });

    test('rechaza venta con stock insuficiente sin efectos parciales', () async {
      final env = await _setup();
      final product = await env.products
          .createProduct(
            ProductDraft(
              storeId: env.store!.id!,
              baseUnitId: env.unitId,
              name: 'Pan',
              salePrice: const Money(100),
              initialStock: 3,
            ),
          )
          .then((r) => r.orNull!);

      final result = await env.sales.registerSale(SaleRequest(
        storeId: env.store!.id!,
        userId: env.vendedor!.id!,
        items: [
          SaleItemInput(
            productId: product.id!,
            quantity: 5,
            unitPrice: const Money(100),
          ),
        ],
      ));

      expect(result.isErr, isTrue);
      expect(result.failure!.code, FailureCode.insufficientStock);
      // Sin efectos parciales: el stock no cambió.
      final stock = await env.inventory.stockOf(product.id!);
      expect(stock.orNull, 3.0);
      final sales = await env.db.saleDao.watchSales(storeId: env.store!.id!).first;
      expect(sales, isEmpty);
    });

    test('rechaza efectivo menor al total', () async {
      final env = await _setup();
      final product = await env.products
          .createProduct(
            ProductDraft(
              storeId: env.store!.id!,
              baseUnitId: env.unitId,
              name: 'Arroz',
              salePrice: const Money(500),
              initialStock: 10,
            ),
          )
          .then((r) => r.orNull!);

      final result = await env.sales.registerSale(SaleRequest(
        storeId: env.store!.id!,
        userId: env.vendedor!.id!,
        items: [
          SaleItemInput(
            productId: product.id!,
            quantity: 1,
            unitPrice: const Money(500),
          ),
        ],
        paymentMethod: PaymentMethod.cash,
        amountReceived: const Money(400),
      ));

      expect(result.isErr, isTrue);
      expect(result.failure!.code, FailureCode.validation);
    });

    test('caja: no permite dos sesiones abiertas ni cerrar cerrada', () async {
      final env = await _setup();
      final register = await env.db.cashDao.defaultRegister();

      await env.cash.openSession(
          registerId: register!.id, userId: env.vendedor!.id!);
      final second = await env.cash.openSession(
          registerId: register.id, userId: env.vendedor!.id!);
      expect(second.isErr, isTrue);
      expect(second.failure!.code, FailureCode.cashSessionAlreadyOpen);

      final open = await env.cash.currentOpenSession(register.id);
      final close = await env.cash.closeSession(
        sessionId: open.orNull!.id!,
        closedBy: env.vendedor!.id!,
        countedAmount: const Money.zero(),
        authorizeDifference: false,
      );
      expect(close.isOk, isTrue);

      final again = await env.cash.closeSession(
        sessionId: open.orNull!.id!,
        closedBy: env.vendedor!.id!,
        countedAmount: const Money.zero(),
        authorizeDifference: false,
      );
      expect(again.isErr, isTrue);
      expect(again.failure!.code, FailureCode.cashSessionClosed);
    });

    test('autenticación con PIN y permisos del rol Vendedor', () async {
      final env = await _setup();
      final login = await env.auth.authenticate('v1', '1234');
      expect(login.isOk, isTrue);
      expect(login.orNull!.permissions, contains('pos.use'));
      expect(login.orNull!.permissions, isNot(contains('users.manage')));

      final bad = await env.auth.authenticate('v1', '9999');
      expect(bad.isErr, isTrue);
    });
  });
}
