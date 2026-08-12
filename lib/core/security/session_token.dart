/// Genera y hashea tokens de sesión locales.
///
/// El token crudo se guarda únicamente en `flutter_secure_storage`; en la
/// base de datos solo se persiste su hash (SHA-256), de modo que un dump de
/// la BD no expone la credencial de sesión.
library;

import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

class SessionToken {
  /// Genera un token aleatorio criptográfico (32 bytes en hex).
  static String generate() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Hash SHA-256 del token (hex).
  static String hash(String token) =>
      sha256.convert(utf8.encode(token)).toString();
}
