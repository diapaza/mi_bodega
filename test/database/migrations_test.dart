import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mi_bodega/core/database/app_database.dart';
import 'package:mi_bodega/features/auth/data/services/bootstrap_service.dart';
import 'package:mi_bodega/features/store/data/repositories/drift_store_repository.dart';

import '../helpers/db_test_utils.dart';

void main() {
  group('Migraciones y persistencia', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('mibodega_migration_');
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    test('crea el esquema en la versión correcta', () async {
      final db = await openTestMemoryDatabase();
      expect(db.schemaVersion, 3);
      // Las tablas existen.
      await db.select(db.stores).get();
      await db.select(db.users).get();
      await db.select(db.products).get();
      await db.select(db.sales).get();
      await db.select(db.inventoryMovements).get();
      await db.select(db.auditLogs).get();
      await db.close();
    });

    test('persiste datos al reabrir el mismo archivo', () async {
      final dbPath = '${tempDir.path}/mibodega.sqlite';

      final db1 = await openTestFileDatabase(dbPath);
      final bootstrap1 = BootstrapService(db1, testPinHasher);
      await bootstrap1.seedRolesAndPermissions();
      await bootstrap1.setup(
        storeName: 'Bodega Persistente',
        ownerFullName: 'Dueño',
        ownerUsername: 'owner',
        ownerRecoveryPin: '9999',
        ownerPin: '1234',
      );
      await db1.close();

      // Reapertura con un nuevo DatabaseManager (simula reinicio de la app).
      final manager = testFileManager(dbPath);
      await manager.init();
      final db2 = manager.database;
      expect(db2.schemaVersion, 3);
      final store = await DriftStoreRepository(db2).getStore();
      expect(store.orNull?.name, 'Bodega Persistente');

      // Los roles y permisos no se duplican (seed idempotente).
      final bootstrap2 = BootstrapService(db2, testPinHasher);
      await bootstrap2.seedRolesAndPermissions();
      final roles = await db2.authDao.allRoles();
      expect(roles.where((r) => r.name == 'Administrador'), hasLength(1));
      await db2.close();
    });

    test('Índices únicos parciales (barcode) rechazan duplicados', () async {
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
      final unitId = await db.catalogDao.insertUnit(UnitsCompanion.insert(
        name: 'Unidad',
        symbol: 'ud',
      ));

      await db.productDao.insertProduct(ProductsCompanion.insert(
        storeId: store.id!,
        baseUnitId: unitId,
        name: 'A',
        barcode: const Value('7750001'),
      ));

      // El segundo producto con el mismo barcode debe violar el índice único.
      expect(
        () => db.productDao.insertProduct(ProductsCompanion.insert(
          storeId: store.id!,
          baseUnitId: unitId,
          name: 'B',
          barcode: const Value('7750001'),
        )),
        throwsA(isA<Object>()),
      );
      await db.close();
    });
  });
}
