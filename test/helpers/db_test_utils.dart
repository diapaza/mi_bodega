import 'dart:io';

import 'package:drift/native.dart';
import 'package:mi_bodega/core/database/app_database.dart';
import 'package:mi_bodega/core/database/database_manager.dart';
import 'package:mi_bodega/core/security/pin_hasher.dart';

/// Abre una base de datos en memoria con PRAGMAs básicos (tests).
Future<AppDatabase> openTestMemoryDatabase() async {
  final db = AppDatabase(NativeDatabase.memory());
  await _applyPragmas(db);
  return db;
}

/// Abre una base de datos respaldada por archivo (tests de backup/restore).
Future<AppDatabase> openTestFileDatabase(String path) async {
  final db = AppDatabase(NativeDatabase(File(path)));
  await _applyPragmas(db);
  return db;
}

/// Crea un [DatabaseManager] sobre un archivo (tests de restore).
DatabaseManager testFileManager(String dbPath) {
  return DatabaseManager.withFile(
    dbFilePath: dbPath,
    opener: () => openTestFileDatabase(dbPath),
  );
}

Future<void> _applyPragmas(AppDatabase db) async {
  await db.customStatement('PRAGMA foreign_keys = ON');
  await db.customStatement('PRAGMA journal_mode = MEMORY');
  await db.customStatement('PRAGMA synchronous = OFF');
}

/// Hasher rápido para tests (el de producción usa más iteraciones).
const testPinHasher = PinHasher(iterations: 1000);
