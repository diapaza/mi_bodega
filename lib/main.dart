import 'dart:io';
import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart' show sqlite3;

import 'app.dart';
import 'core/database/app_database.dart';
import 'core/database/database_manager.dart';
import 'core/di/app_providers.dart';
import 'core/security/secret_store.dart';
import 'features/auth/data/services/bootstrap_service.dart';
import 'features/backup/data/repositories/drift_backup_repository.dart';
import 'features/backup/data/services/backup_coordinator.dart';
import 'features/backup/data/services/backup_service.dart';
import 'features/backup/data/services/google_drive_client.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final docs = await getApplicationDocumentsDirectory();
  final databaseManager = await DatabaseManager.createProduction();

  // Backup del archivo actual antes de que Drift lo migre a una versión mayor.
  await _backupBeforeMigration(databaseManager, docs);

  await databaseManager.init();
  await BootstrapService(databaseManager.database).seedRolesAndPermissions();

  final deviceId = await _readOrCreateDeviceId(databaseManager);
  await initializeDateFormatting('es');
  runApp(
    ProviderScope(
      overrides: [
        databaseManagerProvider.overrideWithValue(databaseManager),
        appDocsDirProvider.overrideWithValue(docs),
        deviceIdProvider.overrideWithValue(deviceId),
      ],
      child: const MiBodegaApp(),
    ),
  );

  // Backup automático (si procede), sin bloquear el arranque.
  unawaited(_autoBackup(databaseManager, docs, deviceId));
}

Future<void> _backupBeforeMigration(
  DatabaseManager manager,
  Directory docs,
) async {
  final file = File(manager.dbFilePath);
  if (!await file.exists()) return;
  try {
    final db = sqlite3.open(file.path);
    final rows = db.select('PRAGMA user_version');
    final diskVersion = rows.first['user_version'] as int?;
    db.close();
    if (diskVersion == null || diskVersion >= AppDatabase.currentSchemaVersion) {
      return;
    }
    final backups = Directory(p.join(docs.path, 'backups'));
    await backups.create(recursive: true);
    await file.copy(
      p.join(backups.path, 'pre_migration_${DateTime.now().millisecondsSinceEpoch}.db'),
    );
  } catch (_) {
    // Best-effort: no debe impedir abrir la app.
  }
}

Future<String> _readOrCreateDeviceId(DatabaseManager manager) async {
  const key = 'device_id';
  final existing = await manager.database.storeDao.getSetting(key);
  if (existing != null && existing.isNotEmpty) return existing;
  final id = List<int>.generate(16, (_) => Random.secure().nextInt(256))
      .map((b) => b.toRadixString(16).padLeft(2, '0'))
      .join();
  await manager.database.storeDao.putSetting(key, id);
  return id;
}

Future<void> _autoBackup(
  DatabaseManager manager,
  Directory docs,
  String deviceId,
) async {
  try {
    final store = await manager.database.storeDao.firstStore();
    if (store == null) return;
    final coordinator = BackupCoordinator(
      databaseManager: manager,
      backupService: BackupService(
        databaseManager: manager,
        backupRepository: DriftBackupRepository(manager.database),
        backupDirProvider: () => Directory(p.join(docs.path, 'backups')),
        photosDirProvider: () => Directory(p.join(docs.path, 'photos')),
        appVersion: '1.0.0',
        deviceId: deviceId,
      ),
      drive: GoogleDriveClient(),
      backupRepository: DriftBackupRepository(manager.database),
      getSetting: manager.database.storeDao.getSetting,
      putSetting: manager.database.storeDao.putSetting,
      readPassphrase: () => SecureSecretStore().read('backup_passphrase'),
      savePassphrase: (v) => SecureSecretStore().write('backup_passphrase', v),
    );
    await coordinator.autoBackupIfDue(storeId: store.id);
  } catch (_) {
    // Silencioso: el backup automático es best-effort.
  }
}
