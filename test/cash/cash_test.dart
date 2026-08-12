import 'package:flutter_test/flutter_test.dart';
import 'package:mi_bodega/core/database/app_database.dart'
    hide AppUser, Store, Product, Unit, Role, ProductUnitConversion, Sale, CashSession;
import 'package:mi_bodega/core/error/result.dart';
import 'package:mi_bodega/core/money/money.dart';
import 'package:mi_bodega/features/auth/data/services/bootstrap_service.dart';
import 'package:mi_bodega/features/cash/data/repositories/drift_cash_repository.dart';
import 'package:mi_bodega/features/cash/domain/entities/cash.dart';
import 'package:mi_bodega/features/products/data/repositories/drift_product_repository.dart';
import 'package:mi_bodega/features/products/domain/entities/product.dart';
import 'package:mi_bodega/features/sales/data/repositories/drift_sale_repository.dart';
import 'package:mi_bodega/features/sales/domain/entities/sale.dart';
import 'package:mi_bodega/features/store/data/repositories/drift_store_repository.dart';
import 'package:mi_bodega/features/store/domain/entities/store.dart';

import '../helpers/db_test_utils.dart';

void main() {
  late AppDatabase db;
  late DriftCashRepository cash;
  late DriftSaleRepository sales;
  late DriftProductRepository products;
  late DriftStoreRepository storeRepo;
  late int registerId;
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
    registerId = (await db.cashDao.defaultRegister())!.id;
    userId = (await db.authDao.allUsers(1)).first.id;
    unitId = (await db.catalogDao.watchActiveUnits().first).first.id;
    cash = DriftCashRepository(db);
    sales = DriftSaleRepository(db);
    products = DriftProductRepository(db);
    storeRepo = DriftStoreRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  Future<CashSession> open({Money amount = const Money(1000)}) async {
    return (await cash.openSession(
      registerId: registerId,
      userId: userId,
      openingAmount: amount,
    ))
        .orNull!;
  }

  Future<void> cashSale(int cents) async {
    final product = (await products.createProduct(ProductDraft(
      storeId: 1,
      baseUnitId: unitId,
      name: 'A',
      salePrice: Money(cents),
      initialStock: 50,
    )))
        .orNull!;
    await sales.registerSale(SaleRequest(
      storeId: 1,
      userId: userId,
      cashSessionId: (await cash.currentOpenSession(registerId)).orNull!.id,
      items: [
        SaleItemInput(
          productId: product.id!,
          quantity: 1,
          unitPrice: Money(cents),
        ),
      ],
      paymentMethod: PaymentMethod.cash,
      amountReceived: Money(cents),
    ));
  }

  group('Resumen y desglose del turno', () {
    test('sessionSummary desglosa apertura, ventas, ingresos, retiros, esperado',
        () async {
      final session = await open(amount: const Money(1000));
      await cashSale(700); // venta en efectivo
      await cash.addManualMovement(
        sessionId: session.id!,
        type: CashMovementType.cashIn,
        amount: const Money(200),
        userId: userId,
        note: 'Cambio',
      );
      await cash.addManualMovement(
        sessionId: session.id!,
        type: CashMovementType.cashOut,
        amount: const Money(100),
        userId: userId,
        note: 'Compra de hielo',
      );

      final summary = (await cash.sessionSummary(session.id!)).orNull!;
      expect(summary.opening.cents, 1000);
      expect(summary.cashSales.cents, 700);
      expect(summary.cashIn.cents, 200);
      expect(summary.cashOut.cents, 100); // magnitud positiva
      expect(summary.expected.cents, 1800); // 1000+700+200-100
    });

    test('salesByMethod separa efectivo de no-efectivo', () async {
      final session = await open();
      await cashSale(700); // cash
      final product = (await products.createProduct(ProductDraft(
        storeId: 1,
        baseUnitId: unitId,
        name: 'B',
        salePrice: const Money(500),
        initialStock: 50,
      )))
          .orNull!;
      await sales.registerSale(SaleRequest(
        storeId: 1,
        userId: userId,
        cashSessionId: session.id,
        items: [
          SaleItemInput(productId: product.id!, quantity: 1, unitPrice: const Money(500)),
        ],
        paymentMethod: PaymentMethod.yape,
      ));

      final byMethod = (await cash.salesByMethod(session.id!)).orNull!;
      expect(byMethod[PaymentMethod.cash]!.cents, 700);
      expect(byMethod[PaymentMethod.yape]!.cents, 500);
    });
  });

  group('Cierre y autorización de diferencias', () {
    test('diferencia dentro del umbral cierra sin autorización', () async {
      final session = await open(amount: const Money(1000));
      final result = await cash.closeSession(
        sessionId: session.id!,
        closedBy: userId,
        countedAmount: const Money(1200), // esperado 1000, diff +200 (S/2)
        authorizeDifference: false,
      );
      expect(result.isOk, isTrue);
      expect(result.orNull!.difference!.cents, 200);
      expect(result.orNull!.isOpen, isFalse);
    });

    test('diferencia mayor al umbral exige autorización', () async {
      final session = await open(amount: const Money(1000));
      await cash.addManualMovement(
        sessionId: session.id!,
        type: CashMovementType.cashIn,
        amount: const Money(1000),
        userId: userId,
        note: 'fondo',
      ); // esperado 2000

      final blocked = await cash.closeSession(
        sessionId: session.id!,
        closedBy: userId,
        countedAmount: const Money(2600), // diff +600 (S/6) > S/5
        authorizeDifference: false,
      );
      expect(blocked.isErr, isTrue);
      expect(blocked.failure!.code, FailureCode.needsAuthorization);

      final authorized = await cash.closeSession(
        sessionId: session.id!,
        closedBy: userId,
        countedAmount: const Money(2600),
        authorizeDifference: true,
      );
      expect(authorized.isOk, isTrue);
      expect(authorized.orNull!.difference!.cents, 600);

      // Auditoría de autorización.
      final audits = await db.auditDao.recentAudits();
      expect(audits.map((a) => a.action), contains('authorize_difference'));
    });

    test('umbral configurable en app_settings', () async {
      await storeRepo.putSetting(SettingKeys.cashDifferenceThreshold, '10000');
      final session = await open(amount: const Money(1000));
      final result = await cash.closeSession(
        sessionId: session.id!,
        closedBy: userId,
        countedAmount: const Money(2000), // diff +1000 (S/10) < S/100
        authorizeDifference: false,
      );
      expect(result.isOk, isTrue);
    });
  });

  group('Ingresos/retiros y auditoría', () {
    test('movimiento manual queda registrado y auditable', () async {
      final session = await open();
      final res = await cash.addManualMovement(
        sessionId: session.id!,
        type: CashMovementType.cashIn,
        amount: const Money(300),
        userId: userId,
        note: 'Pago de préstamo',
      );
      expect(res.isOk, isTrue);
      expect(res.orNull!.amount.cents, 300);

      final movements =
          await cash.watchMovementsForSession(session.id!).first;
      expect(movements.any((m) => m.userName == 'Dueño'), isTrue);

      final audits = await db.auditDao.recentAudits();
      expect(audits.map((a) => a.action), contains('cash_movement'));
    });

    test('no permite una segunda sesión abierta', () async {
      await open();
      final second = await cash.openSession(
        registerId: registerId,
        userId: userId,
      );
      expect(second.isErr, isTrue);
      expect(second.failure!.code, FailureCode.cashSessionAlreadyOpen);
    });
  });

  group('Historial de turnos', () {
    test('muestra los turnos cerrados con sus cifras', () async {
      final session = await open(amount: const Money(500));
      await cash.closeSession(
        sessionId: session.id!,
        closedBy: userId,
        countedAmount: const Money(480),
        authorizeDifference: false,
      );
      final history = await cash.watchSessions(registerId).first;
      expect(history, hasLength(1));
      expect(history.single.expectedAmount!.cents, 500);
      expect(history.single.countedAmount!.cents, 480);
      expect(history.single.difference!.cents, -20);
    });
  });
}
