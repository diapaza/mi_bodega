import 'package:mi_bodega/core/database/app_database.dart' as db;
import 'package:mi_bodega/core/database/daos.dart' as daos;
import 'package:drift/drift.dart';
import 'package:mi_bodega/core/error/failures.dart';
import 'package:mi_bodega/core/error/result.dart';
import 'package:mi_bodega/features/backup/domain/entities/backup.dart';
import 'package:mi_bodega/features/backup/domain/repositories/backup_repository.dart';

class DriftBackupRepository implements BackupRepository {
  final db.AppDatabase database;

  DriftBackupRepository(this.database);

  daos.BackupDao get _dao => database.backupDao;

  @override
  Future<Result<BackupMetadata>> record(BackupMetadata backup) async {
    try {
      final id = await _dao.insertBackup(db.BackupsCompanion.insert(
        storeId: backup.storeId,
        filename: backup.filename,
        driveFileId: backup.driveFileId == null
            ? const Value.absent()
            : Value(backup.driveFileId),
        size: backup.size == null ? const Value.absent() : Value(backup.size),
        checksum: backup.checksum == null
            ? const Value.absent()
            : Value(backup.checksum),
        type: backup.type.dbName,
        status: backup.status.dbName,
        schemaVersion: backup.schemaVersion == null
            ? const Value.absent()
            : Value(backup.schemaVersion),
        appVersion: backup.appVersion == null
            ? const Value.absent()
            : Value(backup.appVersion),
      ));
      final row = await (database.select(database.backups)
            ..where((t) => t.id.equals(id)))
          .getSingleOrNull();
      return Ok(_map(row!));
    } catch (e) {
      return Err(failureFrom(e));
    }
  }

  @override
  Future<Result<void>> markStatus(int id, BackupStatus status) async {
    try {
      await _dao.updateBackupStatus(id, status.dbName);
      return const Ok(null);
    } catch (e) {
      return Err(failureFrom(e));
    }
  }

  @override
  Stream<List<BackupMetadata>> watchBackups({int limit = 50}) {
    return _dao.watchBackups(limit: limit).map((rows) => rows.map(_map).toList());
  }

  @override
  Future<Result<List<BackupMetadata>>> listBackups() async {
    try {
      final rows = await _dao.listBackups();
      return Ok(rows.map(_map).toList());
    } catch (e) {
      return Err(failureFrom(e));
    }
  }

  @override
  Future<Result<void>> remove(int id) async {
    try {
      await _dao.deleteBackup(id);
      return const Ok(null);
    } catch (e) {
      return Err(failureFrom(e));
    }
  }

  BackupMetadata _map(db.Backup b) => BackupMetadata(
        id: b.id,
        storeId: b.storeId,
        filename: b.filename,
        driveFileId: b.driveFileId,
        size: b.size,
        checksum: b.checksum,
        type: BackupTypeX.fromName(b.type),
        status: BackupStatusX.fromName(b.status),
        schemaVersion: b.schemaVersion,
        appVersion: b.appVersion,
        createdAt: b.createdAt,
      );
}
