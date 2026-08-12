import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mi_bodega/core/money/money.dart';
import 'package:mi_bodega/core/error/result.dart';
import 'package:mi_bodega/features/backup/data/repositories/drift_backup_repository.dart';
import 'package:mi_bodega/features/backup/data/services/backup_service.dart';
import 'package:mi_bodega/features/auth/data/services/bootstrap_service.dart';
import 'package:mi_bodega/features/catalog/data/repositories/drift_catalog_repository.dart';
import 'package:mi_bodega/features/catalog/domain/entities/catalog.dart';
import 'package:mi_bodega/features/products/data/repositories/drift_product_repository.dart';
import 'package:mi_bodega/features/products/domain/entities/product.dart';
import 'package:mi_bodega/features/store/data/repositories/drift_store_repository.dart';

import '../helpers/db_test_utils.dart';

void main() {
  group('BackupService', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('mibodega_backup_test_');
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    test('crea un ZIP con manifest e integridad', () async {
      final dbPath = '${tempDir.path}/source.sqlite';
      final manager = testFileManager(dbPath);
      await manager.init();
      final db = manager.database;

      final bootstrap = BootstrapService(db, testPinHasher);
      await bootstrap.seedRolesAndPermissions();
      await bootstrap.setup(
        storeName: 'Bodega Backup',
        ownerFullName: 'Dueño',
        ownerUsername: 'owner',
        ownerRecoveryPin: '9999',
        ownerPin: '1234',
      );
      final store = (await bootstrap.checkState()).store!;

      final catalog = DriftCatalogRepository(db);
      final unit = await catalog
          .createUnit('Unidad', 'ud', UnitType.unit)
          .then((r) => r.orNull!);
      await DriftProductRepository(db).createProduct(ProductDraft(
        storeId: store.id!,
        baseUnitId: unit.id!,
        name: 'Producto Backup',
        salePrice: const Money(100),
        initialStock: 5,
      ));

      final backupDir = Directory('${tempDir.path}/backups');
      final service = BackupService(
        databaseManager: manager,
        backupRepository: DriftBackupRepository(db),
        backupDirProvider: () => backupDir,
        deviceId: 'device-test-1',
        appVersion: '1.0.0-test',
      );

      final result = await service.createBackup(storeId: store.id!);
      expect(result.isOk, isTrue, reason: '$result');
      final meta = result.orNull!;
      expect(meta.filename, endsWith('.zip'));
      expect(meta.checksum, isNotEmpty);
      expect(meta.schemaVersion, 3);

      final zipFile = File('${backupDir.path}/${meta.filename}');
      expect(await zipFile.exists(), isTrue);
      expect(await zipFile.length(), greaterThan(0));
      await db.close();
    });

    test('restaura datos completos en una base nueva tras validar integridad',
        () async {
      final sourcePath = '${tempDir.path}/source.sqlite';
      final sourceManager = testFileManager(sourcePath);
      await sourceManager.init();
      final sourceDb = sourceManager.database;

      final bootstrap = BootstrapService(sourceDb, testPinHasher);
      await bootstrap.seedRolesAndPermissions();
      await bootstrap.setup(
        storeName: 'Bodega Backup',
        ownerFullName: 'Dueño',
        ownerUsername: 'owner',
        ownerRecoveryPin: '9999',
        ownerPin: '1234',
      );
      final store = (await bootstrap.checkState()).store!;
      final catalog = DriftCatalogRepository(sourceDb);
      final unit = await catalog
          .createUnit('Unidad', 'ud', UnitType.unit)
          .then((r) => r.orNull!);
      await DriftProductRepository(sourceDb).createProduct(ProductDraft(
        storeId: store.id!,
        baseUnitId: unit.id!,
        name: 'Producto Backup',
        salePrice: const Money(100),
        initialStock: 5,
      ));

      final backupDir = Directory('${tempDir.path}/backups');
      final service = BackupService(
        databaseManager: sourceManager,
        backupRepository: DriftBackupRepository(sourceDb),
        backupDirProvider: () => backupDir,
        deviceId: 'device-test-1',
      );
      final meta = (await service.createBackup(storeId: store.id!)).orNull!;
      await sourceDb.close();

      // Base nueva vacía donde se restaurará.
      final targetPath = '${tempDir.path}/target.sqlite';
      final targetManager = testFileManager(targetPath);
      await targetManager.init();

      final restoreService = BackupService(
        databaseManager: targetManager,
        backupRepository: DriftBackupRepository(targetManager.database),
        backupDirProvider: () => backupDir,
        deviceId: 'device-test-2',
      );
      final restored = await restoreService
          .restore('${backupDir.path}/${meta.filename}');
      expect(restored.isOk, isTrue, reason: '$restored');
      expect(restored.orNull!.schemaVersion, 3);

      final storeAfter = await DriftStoreRepository(targetManager.database).getStore();
      expect(storeAfter.orNull?.name, 'Bodega Backup');

      final products = await targetManager.database.productDao.searchProducts(
        storeId: storeAfter.orNull!.id!,
        search: 'Producto',
      );
      expect(products, hasLength(1));
      expect(products.first.stock, 5.0);
      await targetManager.database.close();
    });

    test('rechaza respaldos corruptos', () async {
      final targetPath = '${tempDir.path}/target.sqlite';
      final targetManager = testFileManager(targetPath);
      await targetManager.init();

      final corruptPath = '${tempDir.path}/corrupt.zip';
      await File(corruptPath).writeAsBytes([1, 2, 3, 4, 5]);

      final service = BackupService(
        databaseManager: targetManager,
        backupRepository: DriftBackupRepository(targetManager.database),
        backupDirProvider: () => Directory('${tempDir.path}/b'),
        deviceId: 'd',
      );
      final result = await service.restore(corruptPath);
      expect(result.isErr, isTrue);
      expect(result.failure!.code, FailureCode.backupCorrupted);
      await targetManager.database.close();
    });
  });
}
