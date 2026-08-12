import 'package:mi_bodega/core/error/result.dart';
import 'package:mi_bodega/features/backup/domain/entities/backup.dart';

/// Contrato del historial local de respaldos.
abstract interface class BackupRepository {
  Future<Result<BackupMetadata>> record(BackupMetadata backup);

  Future<Result<void>> markStatus(int id, BackupStatus status);

  Stream<List<BackupMetadata>> watchBackups({int limit = 50});

  Future<Result<List<BackupMetadata>>> listBackups();

  Future<Result<void>> remove(int id);
}
