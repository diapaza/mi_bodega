import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mi_bodega/core/database/app_database.dart'
    hide AppUser, Store, Product, Unit, Role, ProductUnitConversion, Sale, Customer;
import 'package:mi_bodega/core/error/result.dart';
import 'package:mi_bodega/core/money/money.dart';
import 'package:mi_bodega/features/auth/data/services/bootstrap_service.dart';
import 'package:mi_bodega/features/customers/data/repositories/drift_customer_repository.dart';
import 'package:mi_bodega/features/products/data/repositories/drift_product_repository.dart';
import 'package:mi_bodega/features/products/domain/entities/product.dart';
import 'package:mi_bodega/features/reports/data/repositories/drift_reports_repository.dart';
import 'package:mi_bodega/features/sales/data/repositories/drift_sale_repository.dart';
import 'package:mi_bodega/features/sales/domain/entities/sale.dart';

import '../helpers/db_test_utils.dart';

void main() {
  late AppDatabase db;
  late DriftSaleRepository sales;
  late DriftProductRepository products;
  late DriftReportsRepository reports;
  late DriftCustomerRepository customers;
  late int storeId;
  late int userId;
  late int unitId;

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
    sales = DriftSaleRepository(db);
    products = DriftProductRepository(db);
    reports = DriftReportsRepository(db);
    customers = DriftCustomerRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  Future<int> makeProduct({required int costCents, required int priceCents, String name = 'P'}) async {
    return (await products.createProduct(ProductDraft(
      storeId: storeId,
      baseUnitId: unitId,
      name: name,
      purchasePrice: Money(costCents),
      salePrice: Money(priceCents),
      initialStock: 100,
    )))
        .orNull!
        .id!;
  }

  Future<SaleDetail> sale(int productId, int qty, {int priceCents = 0, int? discountCents, PaymentMethod method = PaymentMethod.cash}) async {
    final result = await sales.registerSale(SaleRequest(
      storeId: storeId,
      userId: userId,
      items: [
        SaleItemInput(
          productId: productId,
          quantity: qty.toDouble(),
          unitPrice: Money(priceCents),
        ),
      ],
      paymentMethod: method,
      discount: Money(discountCents ?? 0),
      amountReceived: method == PaymentMethod.cash ? Money(priceCents * qty) : null,
    ));
    return result.orNull!;
  }

  Future<void> backdate(int saleId, DateTime date) async {
    await (db.update(db.sales)..where((t) => t.id.equals(saleId)))
        .write(SalesCompanion(saleDate: Value(date)));
  }

  group('Reportes (INGRESO ≠ GANANCIA)', () {
    test('resumen con descuento y exclusión de anuladas', () async {
      final p = await makeProduct(costCents: 200, priceCents: 350);
      await sale(p, 2, priceCents: 350); // ingresos 700, cogs 400
      final cancelled = await sale(p, 1, priceCents: 350);
      await sales.cancelSale(cancelled.sale.id!, userId, reason: 'Error');

      final summary = (await reports.summary(storeId: storeId)).orNull!;
      expect(summary.revenue.cents, 700); // 350 cancelada excluida
      expect(summary.count, 1);
      expect(summary.cogs.cents, 400); // 2 × 200 (snapshot)
      expect(summary.grossProfit.cents, 300);
      expect(summary.margin, closeTo(300 / 700, 0.001));
    });

    test('desglose por método y por vendedor', () async {
      final p = await makeProduct(costCents: 100, priceCents: 500);
      await sale(p, 1, priceCents: 500); // cash
      await sale(p, 2, priceCents: 500, method: PaymentMethod.yape); // 1000 yape

      final summary = (await reports.summary(storeId: storeId)).orNull!;
      expect(summary.revenue.cents, 1500);
      expect(summary.byMethod[PaymentMethod.cash]!.cents, 500);
      expect(summary.byMethod[PaymentMethod.yape]!.cents, 1000);
      expect(summary.byUser[userId]!.cents, 1500);
    });

    test('rango de fechas filtra por periodo', () async {
      final p = await makeProduct(costCents: 100, priceCents: 300);
      await sale(p, 1, priceCents: 300);
      final yesterday = await sale(p, 1, priceCents: 300);
      final now = DateTime.now();
      await backdate(yesterday.sale.id!, now.subtract(const Duration(days: 1)));

      final todaySummary = (await reports.summary(
        storeId: storeId,
        from: DateTime(now.year, now.month, now.day),
        to: DateTime(now.year, now.month, now.day + 1),
      ))
          .orNull!;
      expect(todaySummary.count, 1);
      expect(todaySummary.revenue.cents, 300);

      final last7 = (await reports.summary(
        storeId: storeId,
        from: DateTime(now.year, now.month, now.day - 7),
        to: DateTime(now.year, now.month, now.day + 1),
      ))
          .orNull!;
      expect(last7.count, 2);
    });

    test('top products y serie diaria', () async {
      final a = await makeProduct(costCents: 100, priceCents: 300, name: 'A');
      final b = await makeProduct(costCents: 100, priceCents: 200, name: 'B');
      await sale(a, 3, priceCents: 300);
      await sale(b, 1, priceCents: 200);

      final top = (await reports.topProducts(storeId: storeId)).orNull!;
      expect(top.first.productStock.product.name, 'A');
      expect(top.first.quantity, 3);
      expect(top.first.revenue.cents, 900);
      expect(top.first.cost.cents, 300);
      expect(top.first.profit.cents, 600);

      final daily = (await reports.dailySeries(storeId: storeId)).orNull!;
      expect(daily, hasLength(1));
      expect(daily.first.revenue.cents, 1100);
      expect(daily.first.count, 2);
    });
  });

  group('Clientes', () {
    test('total comprado, última compra e historial', () async {
      final p = await makeProduct(costCents: 100, priceCents: 250);
      final customerId = (await customers.findOrCreate(
        storeId: storeId,
        name: 'Cliente Uno',
        dni: '12345678',
      ))
          .orNull!;

      final s1 = await sales.registerSale(SaleRequest(
        storeId: storeId,
        userId: userId,
        customerId: customerId,
        items: [
          SaleItemInput(productId: p, quantity: 2, unitPrice: const Money(250)),
        ],
        paymentMethod: PaymentMethod.cash,
        amountReceived: const Money(500),
      ));

      final stats = (await customers.customerStats(customerId)).orNull!;
      expect(stats.purchaseCount, 1);
      expect(stats.totalSpent.cents, 500);
      expect(stats.lastPurchaseAt, isNot(null));

      final history = await customers.watchCustomerSales(customerId).first;
      expect(history, hasLength(1));
      expect(history.single.saleNumber, s1.orNull!.sale.saleNumber);

      final byId = (await customers.customerById(customerId)).orNull!;
      expect(byId.name, 'Cliente Uno');
      expect(byId.dni, '12345678');
    });
  });

  group('Historial con filtros y anulación con motivo', () {
    test('watchSalesFiltered por vendedor, método y búsqueda', () async {
      final p = await makeProduct(costCents: 100, priceCents: 300);
      await sale(p, 1, priceCents: 300, method: PaymentMethod.cash);
      final yapeSale = await sale(p, 1, priceCents: 300, method: PaymentMethod.yape);

      final byCash = await sales
          .watchSalesFiltered(storeId: storeId, method: 'cash')
          .first;
      expect(byCash, hasLength(1));

      final byUser = await sales
          .watchSalesFiltered(storeId: storeId, userId: userId)
          .first;
      expect(byUser, hasLength(2));

      final bySearch = await sales
          .watchSalesFiltered(storeId: storeId, search: yapeSale.sale.saleNumber)
          .first;
      expect(bySearch, hasLength(1));
    });

    test('anulación exige motivo y lo persiste', () async {
      final p = await makeProduct(costCents: 100, priceCents: 300);
      final detail = await sale(p, 1, priceCents: 300);

      final noReason = await sales.cancelSale(detail.sale.id!, userId, reason: '  ');
      expect(noReason.isErr, isTrue);
      expect(noReason.failure!.code, FailureCode.validation);

      final ok = await sales.cancelSale(
        detail.sale.id!,
        userId,
        reason: 'Cliente no llevó el producto',
      );
      expect(ok.isOk, isTrue);
      expect(ok.orNull!.sale.status, SaleStatus.cancelled);
      expect(ok.orNull!.sale.cancelReason, 'Cliente no llevó el producto');

      final audits = await db.auditDao.recentAudits();
      expect(audits.map((a) => a.action), contains('cancel'));
    });

    test('migración v3: cancel_reason persiste al reabrir', () async {
      final p = await makeProduct(costCents: 100, priceCents: 300);
      final detail = await sale(p, 1, priceCents: 300);
      await sales.cancelSale(detail.sale.id!, userId, reason: 'Devolución');

      final row = await db.saleDao.saleById(detail.sale.id!);
      expect(row!.cancelReason, 'Devolución');
    });
  });
}
