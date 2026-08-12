import 'package:mi_bodega/core/database/app_database.dart' as db;
import 'package:mi_bodega/core/database/daos.dart' as daos;
import 'package:drift/drift.dart';
import 'package:mi_bodega/core/error/failures.dart';
import 'package:mi_bodega/core/error/result.dart';
import 'package:mi_bodega/features/audit/domain/entities/audit.dart';
import 'package:mi_bodega/features/audit/domain/repositories/audit_repository.dart';

class DriftAuditRepository implements AuditRepository {
  final db.AppDatabase database;

  DriftAuditRepository(this.database);

  daos.AuditDao get _dao => database.auditDao;

  @override
  Future<Result<void>> log(AuditLog log) async {
    try {
      await _dao.insertAudit(db.AuditLogsCompanion.insert(
        userId: log.userId == null ? const Value.absent() : Value(log.userId),
        action: log.action,
        entityType: log.entityType,
        entityId: log.entityId == null ? const Value.absent() : Value(log.entityId),
        beforeJson: log.beforeJson == null ? const Value.absent() : Value(log.beforeJson),
        afterJson: log.afterJson == null ? const Value.absent() : Value(log.afterJson),
      ));
      return const Ok(null);
    } catch (e) {
      return Err(failureFrom(e));
    }
  }

  @override
  Stream<List<AuditLog>> watchAudits({int limit = 100}) {
    return _dao.watchAudits(limit: limit).map((rows) {
      return rows.map(_map).toList();
    });
  }

  AuditLog _map(db.AuditLog a) => AuditLog(
        id: a.id,
        userId: a.userId,
        action: a.action,
        entityType: a.entityType,
        entityId: a.entityId,
        beforeJson: a.beforeJson,
        afterJson: a.afterJson,
        createdAt: a.createdAt,
      );
}
