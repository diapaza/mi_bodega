import 'dart:io';

import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

import 'package:mi_bodega/core/database/app_database.dart';
import 'package:mi_bodega/core/database/app_database.dart' as db;
import 'package:mi_bodega/core/database/daos.dart' as daos;
import 'package:mi_bodega/core/database/database_manager.dart';
import 'package:mi_bodega/core/error/result.dart';
import 'package:mi_bodega/core/error/failures.dart';
import 'package:mi_bodega/features/backup/domain/entities/backup.dart';
import 'package:mi_bodega/features/backup/domain/repositories/backup_repository.dart';
import 'package:mi_bodega/features/store/domain/entities/store.dart';
import 'backup_service.dart';
import 'drive_client.dart';

/// Orquesta el respaldo/restauración local + Google Drive.
class BackupCoordinator {
  final DatabaseManager databaseManager;
  final BackupService backupService;
  final DriveClient drive;
  final BackupRepository backupRepository;
  final Future<String?> Function(String key) getSetting;
  final Future<void> Function(String key, String value) putSetting;
  final Future<String?> Function() readPassphrase;
  final Future<void> Function(String passphrase) savePassphrase;
  final int defaultRetention;

  BackupCoordinator({
    required this.databaseManager,
    required this.backupService,
    required this.drive,
    required this.backupRepository,
    required this.getSetting,
    required this.putSetting,
    required this.readPassphrase,
    required this.savePassphrase,
    this.defaultRetention = 7,
  });

  /// Auditoría sobre la base vigente (tras un restore la conexión se reabre).
  daos.AuditDao get _auditDao => databaseManager.database.auditDao;

  // ---- Cuenta de Google ----

  Future<Result<String?>> connectDrive() async {
    try {
      final email = await drive.signIn();
      if (email != null) {
        await putSetting(SettingKeys.driveAccount, email);
      }
      return Ok(email);
    } catch (e) {
      return Err(failureFrom(e, message: 'No se pudo conectar con Google.'));
    }
  }

  Future<Result<void>> disconnectDrive() async {
    try {
      await drive.signOut();
      await putSetting(SettingKeys.driveAccount, '');
      return const Ok(null);
    } catch (e) {
      return Err(failureFrom(e));
    }
  }

  Future<String?> connectedEmail() => getSetting(SettingKeys.driveAccount);

  Future<bool> get isConnected async {
    final email = await connectedEmail();
    return email != null && email.isNotEmpty;
  }

  // ---- Backup a Drive ----

  Future<Result<BackupMetadata>> backupToDrive({
    required int storeId,
    BackupType type = BackupType.manual,
    String? deviceId,
    String? appVersion,
  }) async {
    try {
      if (!await isConnected) {
        return const Err(Failure(
          code: FailureCode.notFound,
          message: 'Conecta tu cuenta de Google primero.',
        ));
      }
      final includePhotos = await getSetting(SettingKeys.backupIncludePhotos) == 'true';
      final encrypt = await getSetting(SettingKeys.backupEncryption) == 'true';
      String? passphrase;
      if (encrypt) {
        passphrase = await readPassphrase();
        if (passphrase == null || passphrase.isEmpty) {
          return const Err(Failure(
            code: FailureCode.validation,
            message: 'Configura la contraseña de cifrado de los respaldos.',
          ));
        }
      }

      final local = await backupService.createBackup(
        storeId: storeId,
        type: type,
        includePhotos: includePhotos,
        passphrase: passphrase,
        deviceId: deviceId,
        appVersion: appVersion,
      );
      if (local.isErr) return local;
      final meta = local.orNull!;

      final dir = backupService.backupDirProvider();
      final file = File(p.join(dir.path, meta.filename));
      if (!await file.exists()) {
        return const Err(Failure(
          code: FailureCode.deviceError,
          message: 'No se pudo leer el respaldo local.',
        ));
      }
      final bytes = await file.readAsBytes();
      await drive.upload(name: meta.filename, bytes: bytes);
      await backupRepository.markStatus(meta.id!, BackupStatus.uploaded);
      await putSetting(
        SettingKeys.lastBackupAt,
        DateTime.now().toIso8601String(),
      );
      await _auditDao.insertAudit(db.AuditLogsCompanion.insert(
        action: 'backup',
        entityType: 'backup',
        entityId: Value(meta.filename),
        afterJson: Value('{"type":"${type.dbName}","size":${meta.size}}'),
      ));

      await prune();

      return Ok(meta);
    } catch (e) {
      return Err(failureFrom(e, message: 'No se pudo subir el respaldo.'));
    }
  }

  Future<Result<void>> prune() async {
    try {
      final retentionRaw = await getSetting(SettingKeys.backupRetention);
      final retention = int.tryParse(retentionRaw ?? '') ?? defaultRetention;
      final files = await drive.list();
      final ours = files
          .where((f) => f.name.startsWith('mibodega_backup_'))
          .toList()
        ..sort((a, b) =>
            (b.modified ?? DateTime(0)).compareTo(a.modified ?? DateTime(0)));
      for (final f in ours.skip(retention)) {
        await drive.delete(f.id);
      }
      return const Ok(null);
    } catch (e) {
      return Err(failureFrom(e, message: 'No se pudo limpiar backups antiguos.'));
    }
  }

  Future<Result<List<DriveBackupFile>>> listDriveBackups() async {
    try {
      return Ok(await drive.list());
    } catch (e) {
      return Err(failureFrom(e, message: 'No se pudieron listar los respaldos.'));
    }
  }

  // ---- Restauración ----

  Future<Result<RestoreReport>> restoreFromDrive(String fileId) async {
    try {
      final bytes = await drive.download(fileId);
      if (bytes == null) {
        return const Err(Failure(
          code: FailureCode.deviceError,
          message: 'No se pudo descargar el respaldo.',
        ));
      }
      final tmpDir = await Directory.systemTemp.createTemp('mibodega_drive_');
      final tmpFile = File(p.join(tmpDir.path, 'backup.zip'));
      await tmpFile.writeAsBytes(bytes);

      final passphrase = await readPassphrase();
      final result = await backupService.restore(
        tmpFile.path,
        passphrase: passphrase,
      );
      try {
        await tmpDir.delete(recursive: true);
      } catch (_) {}
      if (result.isOk) {
        await _auditDao.insertAudit(db.AuditLogsCompanion.insert(
          action: 'restore',
          entityType: 'backup',
          entityId: Value(fileId),
          afterJson: Value(
            '{"schema":${result.orNull?.schemaVersion ?? 0}}',
          ),
        ));
      }
      return result;
    } catch (e) {
      return Err(failureFrom(e, message: 'No se pudo restaurar el respaldo.'));
    }
  }

  // ---- Auto backup ----

  Future<Result<void>> autoBackupIfDue({required int storeId}) async {
    try {
      if (await getSetting(SettingKeys.autoBackup) != 'true') {
        return const Ok(null);
      }
      if (!await isConnected) return const Ok(null);
      final intervalDays =
          int.tryParse(await getSetting(SettingKeys.backupIntervalDays) ?? '') ??
              1;
      final lastRaw = await getSetting(SettingKeys.lastBackupAt);
      final last = DateTime.tryParse(lastRaw ?? '');
      final due = last == null ||
          DateTime.now().difference(last).inDays >= intervalDays;
      if (!due) return const Ok(null);
      await backupToDrive(storeId: storeId, type: BackupType.automatic);
      return const Ok(null);
    } catch (e) {
      return Err(failureFrom(e, message: 'No se pudo ejecutar el backup automático.'));
    }
  }

  // ---- Backup antes de migración ----

  /// Versión del esquema grabada en el archivo (`PRAGMA user_version`), sin
  /// abrir la base con Drift.
  Future<int?> diskSchemaVersion() async {
    try {
      final file = databaseManager.dbFilePath;
      if (file.isEmpty || !File(file).existsSync()) return null;
      final db = sqlite3.open(file);
      final rows = db.select('PRAGMA user_version');
      final version = rows.first['user_version'] as int?;
      db.close();
      return version;
    } catch (_) {
      return null;
    }
  }

  /// Copia el archivo actual antes de que Drift lo migre a una versión mayor.
  Future<void> backupBeforeMigrationIfNeeded() async {
    final disk = await diskSchemaVersion();
    if (disk == null || disk >= AppDatabase.currentSchemaVersion) return;
    try {
      final dir = backupService.backupDirProvider();
      await dir.create(recursive: true);
      final src = File(databaseManager.dbFilePath);
      if (await src.exists()) {
        await src.copy(p.join(
          dir.path,
          'pre_migration_${DateTime.now().millisecondsSinceEpoch}.db',
        ));
      }
      // Conservar solo las últimas 3 copias pre-migración (evitan acumular
      // archivos en claro).
      final copies = await dir
          .list()
          .where((e) => e.path.contains('pre_migration_'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
      for (final old in copies.take(copies.length - 3)) {
        try {
          await old.delete();
        } catch (_) {}
      }
    } catch (_) {
      // Best-effort: un fallo aquí no debe impedir abrir la app.
    }
  }
}
