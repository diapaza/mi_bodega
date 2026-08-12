import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import 'package:mi_bodega/core/database/database_manager.dart';
import 'package:mi_bodega/core/error/result.dart';
import 'package:mi_bodega/core/error/failures.dart';
import 'package:mi_bodega/features/backup/domain/entities/backup.dart';
import 'package:mi_bodega/features/backup/domain/repositories/backup_repository.dart';
import 'backup_encryption.dart';

/// Servicio de respaldo/restauración local.
///
/// Formato: ZIP con `mibodega.db` (snapshot consistente vía `VACUUM INTO`),
/// `manifest.json` (versiones, checksum SHA-256, tienda, fecha) y, opcional,
/// `photos/*.jpg`. Puede cifrarse con AES-256-GCM (passphrase).
class BackupService {
  final DatabaseManager databaseManager;
  final BackupRepository backupRepository;
  final Directory Function() backupDirProvider;
  final Directory Function()? photosDirProvider;
  final String appVersion;
  final String deviceId;

  BackupService({
    required this.databaseManager,
    required this.backupRepository,
    required this.backupDirProvider,
    this.photosDirProvider,
    this.appVersion = '1.0.0',
    required this.deviceId,
  });

  static const formatVersion = 1;

  /// Crea un respaldo ZIP local y registra su metadato.
  ///
  /// Si [passphrase] no está vacío, el ZIP se cifra antes de guardarse.
  /// Si [includePhotos] es `true`, se incluye la carpeta de fotos.
  Future<Result<BackupMetadata>> createBackup({
    required int storeId,
    BackupType type = BackupType.manual,
    bool includePhotos = false,
    String? passphrase,
    String? deviceId,
    String? appVersion,
  }) async {
    final tempDir = await Directory.systemTemp.createTemp('mibodega_backup_');
    try {
      final db = databaseManager.database;
      final snapshotPath = p.join(tempDir.path, 'snapshot.db');
      final backupDir = backupDirProvider();
      await backupDir.create(recursive: true);

      // 1. Snapshot consistente (sin cerrar la conexión).
      final escaped = snapshotPath.replaceAll("'", "''");
      await db.customStatement("VACUUM INTO '$escaped'");

      // 2. Checksum + tamaño.
      final bytes = await File(snapshotPath).readAsBytes();
      final sha = sha256.convert(bytes).toString();

      // 3. Manifest.
      final now = DateTime.now();
      final store = await _readStoreName(storeId);
      final photoFiles = includePhotos ? await _readPhotos() : const <ArchiveFile>[];
      final manifest = BackupManifest(
        formatVersion: formatVersion,
        schemaVersion: db.schemaVersion,
        appVersion: appVersion ?? this.appVersion,
        storeId: storeId,
        storeName: store,
        deviceId: deviceId ?? this.deviceId,
        createdAt: now.toIso8601String(),
        dbSha256: sha,
        fileCount: 2 + photoFiles.length,
        encrypted: passphrase != null && passphrase.isNotEmpty,
      );

      // 4. ZIP.
      final archive = Archive();
      archive.addFile(
        ArchiveFile('mibodega.db', bytes.length, bytes),
      );
      final manifestBytes = utf8.encode(jsonEncode(manifest.toJson()));
      archive.addFile(
        ArchiveFile('manifest.json', manifestBytes.length, manifestBytes),
      );
      for (final photo in photoFiles) {
        archive.addFile(photo);
      }
      final zipped = ZipEncoder().encode(archive);
      final stored = passphrase != null && passphrase.isNotEmpty
          ? await BackupEncryption.encryptBytes(zipped, passphrase)
          : zipped;

      final stamp = now.millisecondsSinceEpoch;
      final filename = 'mibodega_backup_$stamp.zip';
      final zipFile = File(p.join(backupDir.path, filename));
      await zipFile.writeAsBytes(stored);

      final metadata = await backupRepository.record(BackupMetadata(
        storeId: storeId,
        filename: filename,
        size: stored.length,
        checksum: sha,
        type: type,
        status: BackupStatus.created,
        schemaVersion: db.schemaVersion,
        appVersion: appVersion,
        createdAt: now,
      ));
      return Ok(metadata.orNull!);
    } catch (e) {
      return Err(failureFrom(e));
    } finally {
      try {
        await tempDir.delete(recursive: true);
      } catch (_) {}
    }
  }

  /// Restaura un respaldo validando integridad y compatibilidad.
  ///
  /// Antes de sobrescribir, crea un respaldo de seguridad local del estado
  /// actual. Después reabre la base de datos y ejecuta las migraciones
  /// pendientes. Si el respaldo está cifrado, [passphrase] es obligatoria.
  Future<Result<RestoreReport>> restore(
    String zipPath, {
    String? passphrase,
  }) async {
    try {
      final file = File(zipPath);
      if (!await file.exists()) {
        return const Err(Failure(
          code: FailureCode.deviceError,
          message: 'Archivo de respaldo no encontrado.',
        ));
      }
      final bytes = await file.readAsBytes();

      // Descifrar si aplica (detección: un ZIP cifrado no se puede decodificar).
      List<int> zipBytes = bytes;
      if (passphrase != null && passphrase.isNotEmpty) {
        final decrypted = await BackupEncryption.decryptBytes(bytes, passphrase);
        if (decrypted == null) {
          return const Err(Failure(
            code: FailureCode.backupCorrupted,
            message: 'Contraseña incorrecta o respaldo corrupto.',
          ));
        }
        zipBytes = decrypted;
      }

      final Archive decoded;
      try {
        decoded = ZipDecoder().decodeBytes(zipBytes);
      } catch (_) {
        return Err(Failure(
          code: FailureCode.backupCorrupted,
          message: passphrase != null && passphrase.isNotEmpty
              ? 'No se pudo descifrar el respaldo.'
              : 'El respaldo está cifrado y requiere la contraseña, '
                  'o el archivo no es un respaldo válido.',
        ));
      }
      final manifestFile = decoded.findFile('manifest.json');
      final dbFile = decoded.findFile('mibodega.db');
      if (manifestFile == null || dbFile == null) {
        return const Err(Failure(
          code: FailureCode.backupCorrupted,
          message: 'El respaldo no contiene los archivos esperados.',
        ));
      }

      // Validar manifest.
      final Map<String, Object?> manifestJson;
      try {
        manifestJson =
            jsonDecode(utf8.decode(manifestFile.content)) as Map<String, Object?>;
      } catch (_) {
        return const Err(Failure(
          code: FailureCode.backupCorrupted,
          message: 'El manifest del respaldo es inválido.',
        ));
      }
      final manifest = BackupManifest.fromJson(manifestJson);
      if (manifest.formatVersion != formatVersion) {
        return const Err(Failure(
          code: FailureCode.incompatibleBackup,
          message: 'Versión de formato de respaldo no compatible.',
        ));
      }
      final currentSchema = databaseManager.schemaVersion;
      if (manifest.schemaVersion > currentSchema) {
        return Err(Failure(
          code: FailureCode.incompatibleBackup,
          message: 'El respaldo es de una versión más reciente '
              '(${manifest.schemaVersion} > $currentSchema). Actualiza la app.',
        ));
      }

      // Verificar integridad (SHA-256).
      final dbBytes = dbFile.content as List<int>;
      final sha = sha256.convert(dbBytes).toString();
      if (manifest.dbSha256.isNotEmpty && sha != manifest.dbSha256) {
        return const Err(Failure(
          code: FailureCode.backupCorrupted,
          message: 'La integridad del respaldo no pudo verificarse.',
        ));
      }

      // Restaurar fotos si el respaldo las incluye.
      await _restorePhotos(decoded);

      // Respaldo de seguridad del estado actual.
      final safetyDir = backupDirProvider();
      await safetyDir.create(recursive: true);
      final safetyStamp = DateTime.now().millisecondsSinceEpoch;
      final safetyPath = p.join(safetyDir.path, 'pre_restore_$safetyStamp.db');
      final escapedSafety = safetyPath.replaceAll("'", "''");
      await databaseManager.database
          .customStatement("VACUUM INTO '$escapedSafety'");

      // Swap + reapertura.
      final stagedDir = await Directory.systemTemp.createTemp('mibodega_restore_');
      final stagedPath = p.join(stagedDir.path, 'restore.db');
      await File(stagedPath).writeAsBytes(dbBytes);
      final dbPath = databaseManager.dbFilePath;
      if (dbPath.isEmpty) {
        return const Err(Failure(
          code: FailureCode.deviceError,
          message: 'No se pudo determinar la ruta de la base de datos.',
        ));
      }
      final dbFileOnDisk = File(dbPath);
      if (await dbFileOnDisk.exists()) {
        await dbFileOnDisk.delete();
      }
      await File(stagedPath).copy(dbPath);
      await stagedDir.delete(recursive: true);

      final reopened = await databaseManager.reopen();
      // Drift aplica migraciones pendientes al reabrir (schema <= actual).

      // Limpiar el respaldo de seguridad tras una restauración exitosa
      // (ya no es necesario mantener la copia en claro).
      try {
        final safety = File(safetyPath);
        if (await safety.exists()) {
          await safety.delete();
        }
      } catch (_) {}

      await backupRepository.record(BackupMetadata(
        storeId: manifest.storeId ?? 0,
        filename: 'restore_${DateTime.now().millisecondsSinceEpoch}.zip',
        type: BackupType.manual,
        status: BackupStatus.restored,
        schemaVersion: manifest.schemaVersion,
        appVersion: manifest.appVersion,
        createdAt: DateTime.now(),
      ));

      return Ok(RestoreReport(
        schemaVersion: manifest.schemaVersion,
        dbSchemaVersion: reopened.schemaVersion,
        safetyBackupPath: safetyPath,
      ));
    } catch (e) {
      return Err(failureFrom(e));
    }
  }

  Future<String?> _readStoreName(int storeId) async {
    final row = await (databaseManager.database.select(
              databaseManager.database.stores,
            )
          ..where((t) => t.id.equals(storeId)))
        .getSingleOrNull();
    return row?.name;
  }

  Future<List<ArchiveFile>> _readPhotos() async {
    final photosDir = photosDirProvider?.call();
    if (photosDir == null || !await photosDir.exists()) {
      return const [];
    }
    final files = await photosDir
        .list()
        .where((e) => e is File && p.extension(e.path).toLowerCase() == '.jpg')
        .toList();
    final result = <ArchiveFile>[];
    for (final f in files.cast<File>()) {
      final bytes = await f.readAsBytes();
      result.add(ArchiveFile('photos/${p.basename(f.path)}', bytes.length, bytes));
    }
    return result;
  }

  Future<void> _restorePhotos(Archive archive) async {
    final photosDir = photosDirProvider?.call();
    final photoFiles =
        archive.files.where((f) => f.name.startsWith('photos/')).toList();
    if (photosDir == null || photoFiles.isEmpty) return;
    await photosDir.create(recursive: true);
    for (final f in photoFiles) {
      final target = File(p.join(photosDir.path, p.basename(f.name)));
      await target.writeAsBytes(f.content as List<int>);
    }
  }
}

class RestoreReport {
  final int schemaVersion;
  final int dbSchemaVersion;
  final String safetyBackupPath;

  const RestoreReport({
    required this.schemaVersion,
    required this.dbSchemaVersion,
    required this.safetyBackupPath,
  });
}
