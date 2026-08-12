/// Entidades de respaldo.
library;

enum BackupType { manual, automatic }

enum BackupStatus { created, uploaded, failed, restored }

class BackupMetadata {
  final int? id;
  final int storeId;
  final String filename;
  final String? driveFileId;
  final int? size;
  final String? checksum;
  final BackupType type;
  final BackupStatus status;
  final int? schemaVersion;
  final String? appVersion;
  final DateTime createdAt;

  const BackupMetadata({
    this.id,
    required this.storeId,
    required this.filename,
    this.driveFileId,
    this.size,
    this.checksum,
    required this.type,
    required this.status,
    this.schemaVersion,
    this.appVersion,
    required this.createdAt,
  });
}

extension BackupTypeX on BackupType {
  String get dbName => this == BackupType.automatic ? 'automatic' : 'manual';

  static BackupType fromName(String? name) =>
      name == 'automatic' ? BackupType.automatic : BackupType.manual;
}

extension BackupStatusX on BackupStatus {
  String get dbName {
    return switch (this) {
      BackupStatus.created => 'created',
      BackupStatus.uploaded => 'uploaded',
      BackupStatus.failed => 'failed',
      BackupStatus.restored => 'restored',
    };
  }

  static BackupStatus fromName(String name) {
    return switch (name) {
      'uploaded' => BackupStatus.uploaded,
      'failed' => BackupStatus.failed,
      'restored' => BackupStatus.restored,
      _ => BackupStatus.created,
    };
  }
}

/// Manifest contenido en cada respaldo (ZIP).
class BackupManifest {
  final int formatVersion;
  final int schemaVersion;
  final String appVersion;
  final int? storeId;
  final String? storeName;
  final String deviceId;
  final String createdAt;
  final String dbSha256;
  final int fileCount;
  final bool encrypted;

  const BackupManifest({
    required this.formatVersion,
    required this.schemaVersion,
    required this.appVersion,
    this.storeId,
    this.storeName,
    required this.deviceId,
    required this.createdAt,
    required this.dbSha256,
    required this.fileCount,
    this.encrypted = false,
  });

  Map<String, Object?> toJson() => {
        'format_version': formatVersion,
        'schema_version': schemaVersion,
        'app_version': appVersion,
        'store_id': storeId,
        'store_name': storeName,
        'device_id': deviceId,
        'created_at': createdAt,
        'db_sha256': dbSha256,
        'file_count': fileCount,
        'encrypted': encrypted,
      };

  factory BackupManifest.fromJson(Map<String, Object?> json) => BackupManifest(
        formatVersion: json['format_version'] as int? ?? 1,
        schemaVersion: json['schema_version'] as int? ?? 1,
        appVersion: json['app_version'] as String? ?? '',
        storeId: json['store_id'] as int?,
        storeName: json['store_name'] as String?,
        deviceId: json['device_id'] as String? ?? '',
        createdAt: json['created_at'] as String? ?? '',
        dbSha256: json['db_sha256'] as String? ?? '',
        fileCount: json['file_count'] as int? ?? 1,
        encrypted: json['encrypted'] as bool? ?? false,
      );
}
