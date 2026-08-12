import 'package:mi_bodega/core/error/result.dart';

/// Archivo de respaldo en Google Drive.
class DriveBackupFile {
  final String id;
  final String name;
  final int size;
  final DateTime? modified;

  const DriveBackupFile({
    required this.id,
    required this.name,
    required this.size,
    this.modified,
  });
}

/// Cliente de Google Drive (carpeta privada de la app, scope `drive.file`).
///
/// Abstracción para poder usar una implementación en memoria en tests.
abstract interface class DriveClient {
  Future<bool> isSignedIn();

  /// Inicia sesión con Google; devuelve el correo asociado o `null`.
  Future<String?> signIn();

  Future<void> signOut();

  /// Sube un archivo a la carpeta privada de la app (`appDataFolder`).
  Future<void> upload({required String name, required List<int> bytes});

  Future<List<DriveBackupFile>> list();

  Future<List<int>?> download(String id);

  Future<void> delete(String id);
}

/// Implementación en memoria para tests y desarrollo sin red.
class FakeDriveClient implements DriveClient {
  final Map<String, List<int>> _files = {};
  bool signedIn = false;
  String? email;

  @override
  Future<bool> isSignedIn() async => signedIn;

  @override
  Future<String?> signIn() async {
    signedIn = true;
    email = 'owner@example.com';
    return email;
  }

  @override
  Future<void> signOut() async {
    signedIn = false;
    email = null;
  }

  @override
  Future<void> upload({required String name, required List<int> bytes}) async {
    _files[name] = List.of(bytes);
  }

  @override
  Future<List<DriveBackupFile>> list() async {
    return [
      for (final e in _files.entries)
        DriveBackupFile(
          id: e.key,
          name: e.key,
          size: e.value.length,
          modified: DateTime.now(),
        ),
    ];
  }

  @override
  Future<List<int>?> download(String id) async => _files[id];

  @override
  Future<void> delete(String id) async => _files.remove(id);

  int get fileCount => _files.length;

  bool contains(String name) => _files.containsKey(name);
}

/// Resultado del intento de conectar la cuenta de Google.
class DriveAuthResult {
  final bool signedIn;
  final String? email;
  final Failure? failure;

  const DriveAuthResult({
    required this.signedIn,
    this.email,
    this.failure,
  });
}
