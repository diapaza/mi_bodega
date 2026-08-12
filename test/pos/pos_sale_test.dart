import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mi_bodega/core/database/app_database.dart'
    hide AppUser, Store, Product, Unit, Role, ProductUnitConversion;
import 'package:mi_bodega/core/error/result.dart';
import 'package:mi_bodega/core/money/money.dart';
import 'package:mi_bodega/features/auth/data/services/bootstrap_service.dart';
import 'package:mi_bodega/features/pos/presentation/cart_controller.dart';
import 'package:mi_bodega/features/products/data/repositories/drift_product_repository.dart';
import 'package:mi_bodega/features/products/domain/entities/product.dart';
import 'package:mi_bodega/features/inventory/data/repositories/drift_inventory_repository.dart';
import 'package:mi_bodega/features/inventory/domain/entities/inventory.dart';
import 'package:mi_bodega/features/sales/data/repositories/drift_sale_repository.dart';
import 'package:mi_bodega/features/sales/domain/entities/sale.dart';

import '../helpers/db_test_utils.dart';

/// Flujo del POS: carrito → SaleRequest → registerSale (venta atómica).
void main() {
  late AppDatabase db;
  late DriftSaleRepository sales;
  late DriftProductRepository products;
  late int storeId;
  late int userId;
  late int unitId;
  late int cajaUnitId;

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
    cajaUnitId = await db.catalogDao.insertUnit(UnitsCompanion.insert(
      name: 'Caja',
      symbol: 'caja',
    ));
    sales = DriftSaleRepository(db);
    products = DriftProductRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  Future<Product> makeProduct({
    String name = 'Producto',
    double stock = 50,
    Money price = const Money(350),
  }) async {
    return (await products.createProduct(ProductDraft(
      storeId: storeId,
      baseUnitId: unitId,
      name: name,
      salePrice: price,
      initialStock: stock,
    )))
        .orNull!;
  }

  /// Convierte el estado del carrito a un [SaleRequest] (como hace el POS).
  SaleRequest requestFromCart(CartState cart, {Money? received}) {
    // Pago en efectivo: por defecto se entrega el monto exacto ("Exacto").
    final effective = received ??
        (cart.method == PaymentMethod.cash ? cart.total : null);
    return SaleRequest(
      storeId: storeId,
      userId: userId,
      items: [
        for (final l in cart.lines)
          SaleItemInput(
            productId: l.productId,
            quantity: l.quantity,
            unitId: l.unitId,
            factor: l.factor,
            unitPrice: l.unitPrice,
          ),
      ],
      paymentMethod: cart.method,
      discount: cart.discount,
      amountReceived: effective,
    );
  }

  group('POS → venta (casos normales)', () {
    test('efectivo con vuelto: total 17.50, recibe 20, vuelto 2.50', () async {
      final product = await makeProduct(price: const Money(1750));
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final cart = container.read(cartProvider.notifier);
      cart.add(ProductStock(product, 50));

      final result = await sales.registerSale(
        requestFromCart(container.read(cartProvider), received: const Money(2000)),
      );
      expect(result.isOk, isTrue, reason: '${result.failure}');
      final detail = result.orNull!;
      expect(detail.sale.total.cents, 1750);
      expect(detail.sale.amountReceived!.cents, 2000);
      expect(detail.sale.changeDue!.cents, 250);
      expect(detail.sale.saleNumber, 'V-000001');
      expect(detail.sale.paymentMethod, PaymentMethod.cash);

      // Stock descontado + movimiento + pago + auditoría.
      final stock = await db.inventoryDao.stockOf(product.id!);
      expect(stock, 49);
      final movs = await db.inventoryDao.watchMovements(product.id!).first;
      expect(movs.map((m) => m.movementType), contains('sale_out'));
      final payments = await db.saleDao.paymentsForSale(detail.sale.id!);
      expect(payments.single.amount, 1750);
    });

    test('Yape: pago registrado sin movimiento de caja', () async {
      final product = await makeProduct(price: const Money(500));
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final cart = container.read(cartProvider.notifier);
      cart.add(ProductStock(product, 50));
      cart.setMethod(PaymentMethod.yape);

      final result = await sales.registerSale(
        requestFromCart(container.read(cartProvider)),
      );
      expect(result.isOk, isTrue);
      expect(result.orNull!.sale.paymentMethod, PaymentMethod.yape);
      expect(result.orNull!.sale.amountReceived, isNull);
      expect(result.orNull!.sale.changeDue, isNull);
      final payments = await db.saleDao.paymentsForSale(result.orNull!.sale.id!);
      expect(payments.single.method, 'yape');
    });

    test('venta en caja (conversión ×24): descuenta 24 unidades base', () async {
      final product = (await products.createProduct(ProductDraft(
        storeId: storeId,
        baseUnitId: unitId,
        name: 'Leche caja',
        salePrice: const Money(350),
        initialStock: 48,
      )))
          .orNull!;
      await products.updateProduct(
        product.id!,
        ProductDraft(
          storeId: storeId,
          baseUnitId: unitId,
          name: 'Leche caja',
          salePrice: const Money(350),
        ),
        conversions: [
          ProductUnitConversion(
            productId: product.id!,
            unitId: cajaUnitId,
            factor: 24,
            salePrice: const Money(6000),
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        ],
      );

      final container = ProviderContainer();
      addTearDown(container.dispose);
      final cart = container.read(cartProvider.notifier);
      cart.add(ProductStock(product, 48));
      cart.setUnit(product.id!, cajaUnitId, 24, const Money(6000));

      final result = await sales.registerSale(
        requestFromCart(container.read(cartProvider)),
      );
      expect(result.isOk, isTrue, reason: '${result.failure}');
      expect(result.orNull!.sale.total.cents, 6000); // 1 caja
      final stock = await db.inventoryDao.stockOf(product.id!);
      expect(stock, 24); // 48 − 24
      final mov = (await db.inventoryDao.watchMovements(product.id!).first)
          .firstWhere((m) => m.movementType == 'sale_out');
      expect(mov.quantity, -24);
    });

    test('cliente opcional vacío no crea cliente', () async {
      final product = await makeProduct(price: const Money(100));
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(cartProvider.notifier).add(ProductStock(product, 10));

      final result = await sales.registerSale(
        requestFromCart(container.read(cartProvider)),
      );
      expect(result.isOk, isTrue);
      expect(result.orNull!.sale.customerId, isNull);
    });
  });

  group('POS → venta (casos extremos)', () {
    test('recibido menor al total se rechaza (bloqueado en UI)', () async {
      final product = await makeProduct(price: const Money(1750));
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(cartProvider.notifier).add(ProductStock(product, 10));

      final result = await sales.registerSale(
        requestFromCart(container.read(cartProvider), received: const Money(1000)),
      );
      expect(result.isErr, isTrue);
      expect(result.failure!.code, FailureCode.validation);
    });

    test('stock insuficiente en BD aborta sin efectos parciales', () async {
      final product = await makeProduct(stock: 2, price: const Money(100));
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final cart = container.read(cartProvider.notifier);
      cart.add(ProductStock(product, 2));
      cart.setQuantity(product.id!, 2);

      // Simula una venta concurrente que dejó stock 1.
      await DriftInventoryRepository(db).adjustStock(StockAdjustment(
        productId: product.id!,
        type: MovementType.loss,
        quantity: -1,
        reason: 'venta concurrente',
      ));

      final result = await sales.registerSale(
        requestFromCart(container.read(cartProvider)),
      );
      expect(result.isErr, isTrue);
      expect(result.failure!.code, FailureCode.insufficientStock);
      // Sin efectos parciales.
      expect(await db.inventoryDao.stockOf(product.id!), 1);
      final salesRows = await db.saleDao.watchSales(storeId: storeId).first;
      expect(salesRows, isEmpty);
    });

    test('producto sin stock no se agrega (frecuentes/grid)', () async {
      final product = await makeProduct(stock: 0);
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final added = container
          .read(cartProvider.notifier)
          .add(ProductStock(product, 0));
      expect(added, isFalse);
      expect(container.read(cartProvider).isEmpty, isTrue);
    });

    test('venta anulada repone stock y no puede anularse dos veces', () async {
      final product = await makeProduct(stock: 10, price: const Money(100));
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(cartProvider.notifier).add(ProductStock(product, 10));

      final sale = (await sales.registerSale(
        requestFromCart(container.read(cartProvider)),
      ))
          .orNull!;
      expect(await db.inventoryDao.stockOf(product.id!), 9);

      final cancel = await sales.cancelSale(sale.sale.id!, userId, reason: 'Cliente no pagó');
      expect(cancel.isOk, isTrue);
      expect(await db.inventoryDao.stockOf(product.id!), 10);

      final again = await sales.cancelSale(sale.sale.id!, userId, reason: 'Cliente no pagó');
      expect(again.isErr, isTrue);
    });
  });

  group('Frecuentes (top vendidos)', () {
    test('ordena por cantidad vendida', () async {
      final a = await makeProduct(name: 'Arroz', price: const Money(100));
      final b = await makeProduct(name: 'Fideos', price: const Money(100));
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Venta de 3 de Arroz.
      final cartA = container.read(cartProvider.notifier);
      cartA.add(ProductStock(a, 50));
      cartA.setQuantity(a.id!, 3);
      await sales.registerSale(requestFromCart(container.read(cartProvider)));

      container.read(cartProvider.notifier).clear();
      // Venta de 1 de Fideos.
      final cartB = container.read(cartProvider.notifier);
      cartB.add(ProductStock(b, 50));
      await sales.registerSale(requestFromCart(container.read(cartProvider)));

      final top = (await sales.topSoldProducts(storeId)).orNull!;
      expect(top.first.productStock.product.id, a.id);
      expect(top.first.soldQuantity, 3);
    });
  });
}
