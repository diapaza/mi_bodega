import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mi_bodega/core/di/app_providers.dart';
import 'package:mi_bodega/features/backup/domain/entities/backup.dart';
import 'package:mi_bodega/features/backup/data/services/drive_client.dart';

final driveEmailProvider = FutureProvider<String?>((ref) {
  return ref.watch(backupCoordinatorProvider).connectedEmail();
});

final driveBackupsProvider = FutureProvider<List<DriveBackupFile>>((ref) async {
  final result = await ref.watch(backupCoordinatorProvider).listDriveBackups();
  return result.orNull ?? const [];
});

final localBackupsProvider = StreamProvider<List<BackupMetadata>>((ref) {
  return ref.watch(backupRepositoryProvider).watchBackups();
});
