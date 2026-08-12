import 'package:drift_flutter/drift_flutter.dart';
import 'package:sqlite3/common.dart';

import 'app_database.dart';

/// Abre la base de datos local de la aplicación.
///
/// Configura los PRAGMAs en cada conexión (vía `DriftNativeOptions.setup`),
/// garantizando `foreign_keys` activos y el modo WAL para lecturas
/// concurrentes sin bloqueos.
Future<AppDatabase> openAppDatabase({
  String name = 'mibodega',
  Future<String> Function()? databasePath,
}) async {
  return AppDatabase(
    driftDatabase(
      name: name,
      native: DriftNativeOptions(
        databasePath: databasePath,
        setup: _applyConnectionPragmas,
      ),
    ),
  );
}

/// PRAGMAs aplicados sobre cada conexión abierta.
void _applyConnectionPragmas(CommonDatabase db) {
  db.execute('PRAGMA foreign_keys = ON');
  db.execute('PRAGMA journal_mode = WAL');
  db.execute('PRAGMA synchronous = NORMAL');
  db.execute('PRAGMA busy_timeout = 5000');
}
