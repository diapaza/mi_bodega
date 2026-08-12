import 'dart:io';

import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import 'app_database.dart';
import 'database_connection.dart';

/// Administra el ciclo de vida de la base de datos, incluyendo su cierre y
/// reapertura tras una restauración de respaldo.
class DatabaseManager {
  final Future<AppDatabase> Function() _opener;
  final String _dbFilePath;
  AppDatabase? _database;

  DatabaseManager._(this._opener, this._dbFilePath);

  /// Crea un [DatabaseManager] de producción abriendo `$name.sqlite` en el
  /// directorio de documentos de la aplicación.
  static Future<DatabaseManager> createProduction({String name = 'mibodega'}) async {
    final docs = await getApplicationDocumentsDirectory();
    final dbPath = p.join(docs.path, '$name.sqlite');
    return DatabaseManager._(
      () => openAppDatabase(databasePath: () async => dbPath),
      dbPath,
    );
  }

  /// Crea un [DatabaseManager] con rutas explícitas (tests).
  factory DatabaseManager.withFile({
    required String dbFilePath,
    Future<AppDatabase> Function()? opener,
  }) {
    return DatabaseManager._(
      opener ??
          () async => AppDatabase(NativeDatabase(File(dbFilePath))),
      dbFilePath,
    );
  }

  Future<void> init() async {
    _database ??= await _opener();
  }

  AppDatabase get database {
    final db = _database;
    if (db == null) {
      throw StateError('DatabaseManager no inicializado. Llama a init().');
    }
    return db;
  }

  /// Ruta real del archivo de la base de datos.
  String get dbFilePath => _dbFilePath;

  /// Versión actual del esquema.
  int get schemaVersion => database.schemaVersion;

  /// Cierra y vuelve a abrir la base de datos (usado tras un restore).
  Future<AppDatabase> reopen() async {
    await _database?.close();
    _database = await _opener();
    return _database!;
  }
}
