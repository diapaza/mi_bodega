import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' show sqlite3;

import 'package:mi_bodega/core/database/app_database.dart';
import 'package:mi_bodega/core/error/result.dart';
import 'package:mi_bodega/features/auth/data/services/bootstrap_service.dart';
import 'package:mi_bodega/features/backup/data/repositories/drift_backup_repository.dart';
import 'package:mi_bodega/features/backup/data/services/backup_coordinator.dart';
import 'package:mi_bodega/features/backup/data/services/backup_encryption.dart';
import 'package:mi_bodega/features/backup/data/services/backup_service.dart';
import 'package:mi_bodega/features/backup/data/services/drive_client.dart';
import 'package:mi_bodega/features/store/domain/entities/store.dart';
import 'package:mi_bodega/features/products/data/repositories/drift_product_repository.dart';
import 'package:mi_bodega/features/products/domain/entities/product.dart';

import '../helpers/db_test_utils.dart';

void main() {
  late Directory tempDir;
  late Directory backupDir;
  late Directory photosDir;
  late FakeDriveClient drive;
  late BackupCoordinator coordinator;
  late String dbPath;
  String? passphrase;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('mibodega_drive_');
    backupDir = Directory('${tempDir.path}/backups');
    photosDir = Directory('${tempDir.path}/photos');
    drive = FakeDriveClient();

    dbPath = '${tempDir.path}/mibodega.sqlite';
    final manager = testFileManager(dbPath);
    await manager.init();
    final bootstrap = BootstrapService(manager.database, testPinHasher);
    await bootstrap.seedRolesAndPermissions();
    await bootstrap.setup(
      storeName: 'Bodega Drive',
      ownerFullName: 'Dueño',
      ownerUsername: 'owner',
      ownerPin: '1234',
      ownerRecoveryPin: '9999',
    );

    final service = BackupService(
      databaseManager: manager,
      backupRepository: DriftBackupRepository(manager.database),
      backupDirProvider: () => backupDir,
      photosDirProvider: () => photosDir,
      appVersion: '1.0.0',
      deviceId: 'device-test',
    );

    coordinator = BackupCoordinator(
      databaseManager: manager,
      backupService: service,
      drive: drive,
      backupRepository: DriftBackupRepository(manager.database),
      getSetting: manager.database.storeDao.getSetting,
      putSetting: manager.database.storeDao.putSetting,
      readPassphrase: () async => passphrase,
      savePassphrase: (v) async => passphrase = v,
    );
  });

  tearDown(() async {
    await coordinator.databaseManager.database.close();
    await tempDir.delete(recursive: true);
  });

  group('Backup a Drive (roundtrip con Fake)', () {
    test('sube, lista, descarga y restaura conservando los datos', () async {
      await coordinator.connectDrive();

      final unitId = (await coordinator.databaseManager.database.catalogDao
              .watchActiveUnits().first)
          .first
          .id;
      await DriftProductRepository(coordinator.databaseManager.database)
          .createProduct(ProductDraft(
        storeId: 1,
        baseUnitId: unitId,
        name: 'Producto Original',
        initialStock: 7,
      ));

      final result = await coordinator.backupToDrive(storeId: 1);
      expect(result.isOk, isTrue, reason: '${result.failure}');
      expect(drive.fileCount, 1);
      expect(drive.contains(result.orNull!.filename), isTrue);

      // Restaurar en la misma base: el nombre de la tienda se conserva.
      final files = await coordinator.listDriveBackups();
      final restored = await coordinator.restoreFromDrive(files.orNull!.first.id);
      expect(restored.isOk, isTrue, reason: '${restored.failure}');

      final db = coordinator.databaseManager.database;
      final store = await db.storeDao.firstStore();
      expect(store!.name, 'Bodega Drive');
      final products = await db.productDao.searchProducts(
        storeId: 1,
        search: 'Producto Original',
      );
      expect(products, hasLength(1));
      expect(products.first.stock, 7);
    });

    test('sin cuenta conectada no sube', () async {
      final result = await coordinator.backupToDrive(storeId: 1);
      expect(result.isErr, isTrue);
      expect(drive.fileCount, 0);
    });
  });

  group('Cifrado', () {
    test('cifra el respaldo y restaura con la contraseña', () async {
      await coordinator.connectDrive();
      await coordinator.putSetting(SettingKeys.backupEncryption, 'true');
      await coordinator.savePassphrase('secreto-123');
      passphrase = 'secreto-123';

      final result = await coordinator.backupToDrive(storeId: 1);
      expect(result.isOk, isTrue);

      // El contenido en Drive no es un ZIP descifrable sin clave.
      final stored = await drive.download(result.orNull!.filename);
      final decrypted = await BackupEncryption.decryptBytes(stored!, 'incorrecta');
      expect(decrypted, isNull);

      final files = await coordinator.listDriveBackups();
      final restored = await coordinator.restoreFromDrive(files.orNull!.first.id);
      expect(restored.isOk, isTrue, reason: '${restored.failure}');
    });

    test('contraseña incorrecta rechaza la restauración', () async {
      await coordinator.connectDrive();
      await coordinator.putSetting(SettingKeys.backupEncryption, 'true');
      await coordinator.savePassphrase('correcta');
      passphrase = 'correcta';
      await coordinator.backupToDrive(storeId: 1);

      passphrase = 'incorrecta';
      final files = await coordinator.listDriveBackups();
      final restored = await coordinator.restoreFromDrive(files.orNull!.first.id);
      expect(restored.isErr, isTrue);
      expect(restored.failure!.code, FailureCode.backupCorrupted);
    });
  });

  group('Versionado y auto-backup', () {
    test('prune conserva solo la retención (7)', () async {
      await coordinator.connectDrive();
      for (var i = 0; i < 10; i++) {
        await drive.upload(name: 'mibodega_backup_$i.zip', bytes: List.filled(100, i));
      }
      await coordinator.prune();
      expect(drive.fileCount, 7);
    });

    test('auto-backup por intervalo', () async {
      await coordinator.connectDrive();
      await coordinator.putSetting(SettingKeys.autoBackup, 'true');
      // Sin lastBackupAt → debe ejecutarse.
      await coordinator.autoBackupIfDue(storeId: 1);
      expect(drive.fileCount, 1);

      // Reciente → no vuelve a subir.
      await coordinator.autoBackupIfDue(storeId: 1);
      expect(drive.fileCount, 1);
    });
  });

  group('Fotos y backup pre-migración', () {
    test('las fotos viajan y se restauran', () async {
      await photosDir.create(recursive: true);
      await File('${photosDir.path}/p1.jpg').writeAsBytes(List.filled(64, 1));
      await coordinator.connectDrive();
      await coordinator.putSetting(SettingKeys.backupIncludePhotos, 'true');

      await coordinator.backupToDrive(storeId: 1);
      final files = await coordinator.listDriveBackups();
      await coordinator.restoreFromDrive(files.orNull!.first.id);

      expect(File('${photosDir.path}/p1.jpg').existsSync(), isTrue);
    });

    test('backup pre-migración copia el archivo si la versión en disco es menor',
        () async {
      // Crear un archivo con user_version 1 (sin abrir con Drift).
      final legacy = '${tempDir.path}/legacy.sqlite';
      final db = sqlite3.open(legacy);
      db.execute('PRAGMA user_version = 1');
      db.close();

      final dummy = AppDatabase(NativeDatabase.memory());
      final manager = testFileManager(legacy);
      final service = BackupService(
        databaseManager: manager,
        backupRepository: DriftBackupRepository(dummy),
        backupDirProvider: () => backupDir,
        appVersion: '1.0.0',
        deviceId: 'd',
      );
      final coord = BackupCoordinator(
        databaseManager: manager,
        backupService: service,
        drive: drive,
        backupRepository: DriftBackupRepository(dummy),
        getSetting: (_) async => null,
        putSetting: (_, _) async {},
        readPassphrase: () async => null,
        savePassphrase: (_) async {},
      );

      expect(await coord.diskSchemaVersion(), 1);
      await coord.backupBeforeMigrationIfNeeded();
      final backups = await backupDir.list().toList();
      expect(backups.any((f) => f.path.contains('pre_migration_')), isTrue);
      await dummy.close();
    });
  });
}
