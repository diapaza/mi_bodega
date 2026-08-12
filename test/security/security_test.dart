import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mi_bodega/core/database/app_database.dart'
    hide AppUser, Store, Product, Unit, Role, ProductUnitConversion, Sale, Customer;
import 'package:mi_bodega/core/error/result.dart';
import 'package:mi_bodega/core/money/money.dart';
import 'package:mi_bodega/core/security/permission_guard.dart';
import 'package:mi_bodega/core/security/session_store.dart';
import 'package:mi_bodega/features/auth/data/repositories/drift_auth_repository.dart';
import 'package:mi_bodega/features/auth/data/services/auth_service.dart';
import 'package:mi_bodega/features/auth/data/services/bootstrap_service.dart';
import 'package:mi_bodega/features/auth/data/services/lockout_service.dart';
import 'package:mi_bodega/features/auth/data/services/session_service.dart';
import 'package:mi_bodega/features/auth/domain/entities/auth.dart';
import 'package:mi_bodega/features/backup/data/repositories/drift_backup_repository.dart';
import 'package:mi_bodega/features/backup/data/services/backup_coordinator.dart';
import 'package:mi_bodega/features/backup/data/services/backup_service.dart';
import 'package:mi_bodega/features/backup/data/services/drive_client.dart';
import 'package:mi_bodega/features/customers/data/repositories/drift_customer_repository.dart';
import 'package:mi_bodega/features/products/data/repositories/drift_product_repository.dart';
import 'package:mi_bodega/features/products/domain/entities/product.dart';
import 'package:mi_bodega/features/sales/data/repositories/drift_sale_repository.dart';
import 'package:mi_bodega/features/sales/domain/entities/sale.dart';

import '../helpers/db_test_utils.dart';

void main() {
  group('PermissionGuard', () {
    test('permite con el permiso presente', () {
      final r = ensureAllowed({'sales.create', 'users.manage'}, 'users.manage');
      expect(r.isOk, isTrue);
    });

    test('rechaza sin el permiso (forbidden)', () {
      final r = ensureAllowed({'sales.create'}, 'users.manage');
      expect(r.isErr, isTrue);
      expect(r.failure!.code, FailureCode.forbidden);
    });
  });

  group('Auditoría de seguridad', () {
    late AppDatabase db;
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
      userId = (await db.authDao.allUsers(1)).first.id;
      unitId = (await db.catalogDao.watchActiveUnits().first).first.id;
    });

    tearDown(() async {
      await db.close();
    });

    Future<List<String>> actions() async =>
        (await db.auditDao.recentAudits()).map((a) => a.action).toList();

    test('cambio de permisos de rol queda auditado', () async {
      final repo = DriftAuthRepository(db, testPinHasher);
      final all = (await repo.allPermissions()).orNull!;
      final ids = all.map((p) => p.id!).toList();
      final role = (await repo.createRole(
        const RoleDraft(name: 'Rol prueba', permissionIds: []),
      ))
          .orNull!;
      await repo.updateRole(
        Role(
          id: role.id,
          name: 'Rol prueba',
          isSystem: false,
          active: true,
          createdAt: role.createdAt,
          updatedAt: role.updatedAt,
        ),
        permissionIds: ids,
      );
      expect(await actions(), contains('change_permissions'));
    });

    test('cambio de precio de producto queda auditado con before/after', () async {
      final products = DriftProductRepository(db);
      final product = (await products.createProduct(ProductDraft(
        storeId: 1,
        baseUnitId: unitId,
        name: 'A',
        salePrice: const Money(500),
        initialStock: 5,
      )))
          .orNull!;
      await products.updateProduct(
        product.id!,
        ProductDraft(
          storeId: 1,
          baseUnitId: unitId,
          name: 'A',
          salePrice: const Money(700),
        ),
      );

      final audits = await db.auditDao.recentAudits();
      final priceChange =
          audits.firstWhere((a) => a.action == 'price_change');
      expect(priceChange.beforeJson, contains('"sale":500'));
      expect(priceChange.afterJson, contains('"sale":700'));
    });

    test('logout queda auditado', () async {
      final repo = DriftAuthRepository(db, testPinHasher);
      final auth = AuthService(
        repo,
        SessionService(MemorySessionStore(), db.storeDao, db.authDao),
        LockoutService(db.storeDao),
        db.auditDao,
      );
      await auth.logout(userId: userId);
      expect(await actions(), contains('logout'));
    });

    test('el DNI del cliente no aparece en la auditoría de la venta', () async {
      final customers = DriftCustomerRepository(db);
      final products = DriftProductRepository(db);
      final sales = DriftSaleRepository(db);
      final customerId = (await customers.findOrCreate(
        storeId: 1,
        name: 'Cliente DNI',
        dni: '12345678',
      ))
          .orNull!;
      final product = (await products.createProduct(ProductDraft(
        storeId: 1,
        baseUnitId: unitId,
        name: 'A',
        salePrice: const Money(200),
        initialStock: 5,
      )))
          .orNull!;
      await sales.registerSale(SaleRequest(
        storeId: 1,
        userId: userId,
        customerId: customerId,
        items: [
          SaleItemInput(productId: product.id!, quantity: 1, unitPrice: const Money(200)),
        ],
        paymentMethod: PaymentMethod.cash,
        amountReceived: const Money(200),
      ));

      final audits = await db.auditDao.recentAudits();
      final saleAudit = audits.firstWhere((a) => a.entityType == 'sale');
      expect(saleAudit.afterJson, isNot(contains('12345678')));
      expect(saleAudit.afterJson, isNot(contains('DNI')));
    });
  });

  group('Backup: auditoría y limpieza', () {
    late Directory tempDir;
    late Directory backupDir;
    late FakeDriveClient drive;
    late BackupCoordinator coordinator;
    late AppDatabase db;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('mibodega_sec_');
      backupDir = Directory('${tempDir.path}/backups');
      drive = FakeDriveClient();
      final dbPath = '${tempDir.path}/mibodega.sqlite';
      final manager = testFileManager(dbPath);
      await manager.init();
      db = manager.database;
      final bootstrap = BootstrapService(db, testPinHasher);
      await bootstrap.seedRolesAndPermissions();
      await bootstrap.setup(
        storeName: 'Bodega',
        ownerFullName: 'Dueño',
        ownerUsername: 'owner',
        ownerPin: '1234',
        ownerRecoveryPin: '9999',
      );
      coordinator = BackupCoordinator(
        databaseManager: manager,
        backupService: BackupService(
          databaseManager: manager,
          backupRepository: DriftBackupRepository(db),
          backupDirProvider: () => backupDir,
          appVersion: '1.0.0',
          deviceId: 'd',
        ),
        drive: drive,
        backupRepository: DriftBackupRepository(db),
        getSetting: db.storeDao.getSetting,
        putSetting: db.storeDao.putSetting,
        readPassphrase: () async => null,
        savePassphrase: (_) async {},
      );
    });

    tearDown(() async {
      await db.close();
      await tempDir.delete(recursive: true);
    });

    test('backup y restore quedan auditados', () async {
      await coordinator.connectDrive();
      await coordinator.backupToDrive(storeId: 1);
      var audits = (await db.auditDao.recentAudits()).map((a) => a.action);
      expect(audits, contains('backup'));

      final files = await coordinator.listDriveBackups();
      await coordinator.restoreFromDrive(files.orNull!.first.id);
      audits = (await coordinator.databaseManager.database.auditDao
              .recentAudits())
          .map((a) => a.action);
      expect(audits, contains('restore'));
    });

    test('el safety backup se elimina tras un restore exitoso', () async {
      await coordinator.connectDrive();
      await coordinator.backupToDrive(storeId: 1);
      final files = await coordinator.listDriveBackups();
      final result = await coordinator.restoreFromDrive(files.orNull!.first.id);
      expect(result.isOk, isTrue, reason: '${result.failure}');

      final safetyFiles = await backupDir
          .list()
          .where((e) => e.path.contains('pre_restore_'))
          .toList();
      expect(safetyFiles, isEmpty);
    });
  });
}
