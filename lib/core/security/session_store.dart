/// Almacenamiento seguro del token de sesión.
///
/// Abstracción para poder usar secure storage en producción y una
/// implementación en memoria en tests/widget tests.
library;

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class SessionStore {
  Future<String?> readToken();

  Future<void> writeToken(String token);

  Future<void> deleteToken();
}

class SecureSessionStore implements SessionStore {
  static const _key = 'mibodega_session_token';

  final FlutterSecureStorage _storage;

  SecureSessionStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  @override
  Future<String?> readToken() => _storage.read(key: _key);

  @override
  Future<void> writeToken(String token) =>
      _storage.write(key: _key, value: token);

  @override
  Future<void> deleteToken() => _storage.delete(key: _key);
}

class MemorySessionStore implements SessionStore {
  String? _token;

  MemorySessionStore([this._token]);

  @override
  Future<String?> readToken() async => _token;

  @override
  Future<void> writeToken(String token) async => _token = token;

  @override
  Future<void> deleteToken() async => _token = null;
}
