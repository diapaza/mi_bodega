import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:mi_bodega/core/database/app_database.dart';
import 'package:mi_bodega/core/database/database_manager.dart';
import 'package:mi_bodega/core/security/secret_store.dart';
import 'package:mi_bodega/core/security/session_store.dart';
import 'package:mi_bodega/features/auth/data/repositories/drift_auth_repository.dart';
import 'package:mi_bodega/features/auth/data/services/auth_service.dart';
import 'package:mi_bodega/features/auth/data/services/bootstrap_service.dart';
import 'package:mi_bodega/features/auth/data/services/lockout_service.dart';
import 'package:mi_bodega/features/auth/data/services/session_service.dart';
import 'package:mi_bodega/features/auth/domain/repositories/auth_repository.dart';
import 'package:mi_bodega/features/backup/data/repositories/drift_backup_repository.dart';
import 'package:mi_bodega/features/backup/data/services/backup_coordinator.dart';
import 'package:mi_bodega/features/backup/data/services/backup_service.dart';
import 'package:mi_bodega/features/backup/data/services/drive_client.dart';
import 'package:mi_bodega/features/backup/data/services/google_drive_client.dart';
import 'package:mi_bodega/features/backup/domain/repositories/backup_repository.dart';
import 'package:mi_bodega/features/catalog/data/repositories/drift_catalog_repository.dart';
import 'package:mi_bodega/features/catalog/domain/repositories/catalog_repository.dart';
import 'package:mi_bodega/features/inventory/data/repositories/drift_inventory_repository.dart';
import 'package:mi_bodega/features/inventory/domain/repositories/inventory_repository.dart';
import 'package:mi_bodega/features/cash/data/repositories/drift_cash_repository.dart';
import 'package:mi_bodega/features/cash/domain/repositories/cash_repository.dart';
import 'package:mi_bodega/features/sales/data/repositories/drift_sale_repository.dart';
import 'package:mi_bodega/features/sales/domain/repositories/sale_repository.dart';
import 'package:mi_bodega/features/customers/data/repositories/drift_customer_repository.dart';
import 'package:mi_bodega/features/customers/domain/repositories/customer_repository.dart';
import 'package:mi_bodega/features/reports/data/repositories/drift_reports_repository.dart';
import 'package:mi_bodega/features/reports/domain/repositories/reports_repository.dart';
import 'package:mi_bodega/features/products/data/repositories/drift_product_repository.dart';
import 'package:mi_bodega/features/products/data/services/photo_service.dart';
import 'package:mi_bodega/features/products/domain/repositories/product_repository.dart';
import 'package:mi_bodega/features/purchases/data/repositories/drift_purchase_repository.dart';
import 'package:mi_bodega/features/purchases/data/repositories/drift_supplier_repository.dart';
import 'package:mi_bodega/features/purchases/domain/repositories/purchase_repository.dart';
import 'package:mi_bodega/features/store/data/repositories/drift_store_repository.dart';
import 'package:mi_bodega/features/store/domain/repositories/store_repository.dart';

/// Administrador de la base de datos (inyectado en `main`).
final databaseManagerProvider = Provider<DatabaseManager>(
  (_) => throw UnimplementedError('databaseManagerProvider debe sobrescribirse'),
);

/// Instancia activa de la base de datos.
final databaseProvider = Provider<AppDatabase>(
  (ref) => ref.watch(databaseManagerProvider).database,
);

final storeDaoProvider = Provider((ref) => ref.watch(databaseProvider).storeDao);
final authDaoProvider = Provider((ref) => ref.watch(databaseProvider).authDao);
final auditDaoProvider = Provider((ref) => ref.watch(databaseProvider).auditDao);

final bootstrapServiceProvider = Provider(
  (ref) => BootstrapService(ref.watch(databaseProvider)),
);

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => DriftAuthRepository(ref.watch(databaseProvider)),
);

final storeRepositoryProvider = Provider<StoreRepository>(
  (ref) => DriftStoreRepository(ref.watch(databaseProvider)),
);

final catalogRepositoryProvider = Provider<CatalogRepository>(
  (ref) => DriftCatalogRepository(ref.watch(databaseProvider)),
);

final productRepositoryProvider = Provider<ProductRepository>(
  (ref) => DriftProductRepository(ref.watch(databaseProvider)),
);

final inventoryRepositoryProvider = Provider<InventoryRepository>(
  (ref) => DriftInventoryRepository(ref.watch(databaseProvider)),
);

final purchaseRepositoryProvider = Provider<PurchaseRepository>(
  (ref) => DriftPurchaseRepository(ref.watch(databaseProvider)),
);

final supplierRepositoryProvider = Provider<SupplierRepository>(
  (ref) => DriftSupplierRepository(ref.watch(databaseProvider)),
);

final cashRepositoryProvider = Provider<CashRepository>(
  (ref) => DriftCashRepository(ref.watch(databaseProvider)),
);

final saleRepositoryProvider = Provider<SaleRepository>(
  (ref) => DriftSaleRepository(ref.watch(databaseProvider)),
);

final customerRepositoryProvider = Provider<CustomerRepository>(
  (ref) => DriftCustomerRepository(ref.watch(databaseProvider)),
);

final reportsRepositoryProvider = Provider<ReportsRepository>(
  (ref) => DriftReportsRepository(ref.watch(databaseProvider)),
);

/// Servicio de fotos (almacenamiento en documents/photos).
final photoServiceProvider = Provider<PhotoService>(
  (ref) => LocalPhotoService(
    baseDir: () async => (await getApplicationDocumentsDirectory()).path,
  ),
);

/// Almacén del token de sesión (secure storage en producción).
final sessionStoreProvider = Provider<SessionStore>(
  (_) => SecureSessionStore(),
);

final sessionServiceProvider = Provider(
  (ref) => SessionService(
    ref.watch(sessionStoreProvider),
    ref.watch(storeDaoProvider),
    ref.watch(authDaoProvider),
  ),
);

final lockoutServiceProvider = Provider(
  (ref) => LockoutService(ref.watch(storeDaoProvider)),
);

final authServiceProvider = Provider(
  (ref) => AuthService(
    ref.watch(authRepositoryProvider),
    ref.watch(sessionServiceProvider),
    ref.watch(lockoutServiceProvider),
    ref.watch(auditDaoProvider),
  ),
);

/// Directorio de documentos de la app (sobrescrito en `main`).
final appDocsDirProvider = Provider<Directory>(
  (_) => throw UnimplementedError('appDocsDirProvider debe sobrescribirse'),
);

/// Almacén seguro de secretos (passphrase del respaldo).
final secretStoreProvider = Provider<SecretStore>(
  (_) => SecureSecretStore(),
);

/// Cliente de Google Drive (sobrescribir con `FakeDriveClient` en tests).
final driveClientProvider = Provider<DriveClient>(
  (_) => GoogleDriveClient(),
);

final backupRepositoryProvider = Provider<BackupRepository>(
  (ref) => DriftBackupRepository(ref.watch(databaseProvider)),
);

/// Identificador de dispositivo (persistido y sobrescrito en `main`).
final deviceIdProvider = Provider<String>((_) => 'device');

final backupServiceProvider = Provider<BackupService>((ref) {
  final docs = ref.watch(appDocsDirProvider).path;
  final driveRepo = ref.watch(backupRepositoryProvider);
  return BackupService(
    databaseManager: ref.watch(databaseManagerProvider),
    backupRepository: driveRepo,
    backupDirProvider: () => Directory(p.join(docs, 'backups')),
    photosDirProvider: () => Directory(p.join(docs, 'photos')),
    appVersion: '1.0.0',
    deviceId: 'pending',
  );
});

/// Passphrase del respaldo (persistida en secure storage).
final backupPassphraseProvider = Provider<String?>((ref) {
  return null;
});

final backupCoordinatorProvider = Provider<BackupCoordinator>((ref) {
  final storeDao = ref.watch(databaseProvider).storeDao;
  final passphraseKey = 'backup_passphrase';
  final secrets = ref.watch(secretStoreProvider);
  final service = ref.watch(backupServiceProvider);
  // El deviceId real se resuelve de forma asíncrona; se actualiza tras init.
  return BackupCoordinator(
    databaseManager: ref.watch(databaseManagerProvider),
    backupService: service,
    drive: ref.watch(driveClientProvider),
    backupRepository: ref.watch(backupRepositoryProvider),
    getSetting: storeDao.getSetting,
    putSetting: storeDao.putSetting,
    readPassphrase: () => secrets.read(passphraseKey),
    savePassphrase: (v) => secrets.write(passphraseKey, v),
  );
});
