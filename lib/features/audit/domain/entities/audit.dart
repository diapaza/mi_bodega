/// Entidad de auditoría.
library;

class AuditLog {
  final int? id;
  final int? userId;
  final String action;
  final String entityType;
  final String? entityId;
  final String? beforeJson;
  final String? afterJson;
  final DateTime createdAt;

  const AuditLog({
    this.id,
    this.userId,
    required this.action,
    required this.entityType,
    this.entityId,
    this.beforeJson,
    this.afterJson,
    required this.createdAt,
  });
}
