import 'package:mi_bodega/core/error/result.dart';
import 'package:mi_bodega/features/audit/domain/entities/audit.dart';

/// Contrato de auditoría.
abstract interface class AuditRepository {
  Future<Result<void>> log(AuditLog log);

  Stream<List<AuditLog>> watchAudits({int limit = 100});
}
