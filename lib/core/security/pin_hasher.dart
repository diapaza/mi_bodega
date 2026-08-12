import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Hashea PINs con PBKDF2-HMAC-SHA256.
///
/// El PIN nunca se guarda en claro. Cada hash usa un salt aleatorio.
/// Formato almacenado: `pbkdf2_sha256$<iteraciones>$<salt_b64>$<hash_b64>`.
class PinHasher {
  final int iterations;

  const PinHasher({this.iterations = 120000});

  /// Verifica un PIN contra un hash almacenado.
  bool verify(String pin, String storedHash) {
    final parts = storedHash.split(r'$');
    if (parts.length != 4 || parts[0] != 'pbkdf2_sha256') {
      return false;
    }
    final salt = base64Url.decode(parts[2]);
    final expected = base64Url.decode(parts[3]);
    final computed = _derive(pin, salt, int.parse(parts[1]));
    return _constantTimeEquals(computed, expected);
  }

  /// Genera un hash seguro para el PIN dado.
  String hash(String pin) {
    final salt = _randomSalt(16);
    final derived = _derive(pin, salt, iterations);
    return 'pbkdf2_sha256\$$iterations\$'
        '${base64Url.encode(salt)}\$'
        '${base64Url.encode(derived)}';
  }

  Uint8List _derive(String pin, Uint8List salt, int rounds) {
    final key = Hmac(sha256, utf8.encode(pin));
    final input = Uint8List(salt.length + 4)..setAll(0, salt);
    ByteData.view(input.buffer).setUint32(salt.length, 1, Endian.big);

    var u = key.convert(input).bytes;
    var result = Uint8List.fromList(u);
    for (var i = 1; i < rounds; i++) {
      u = key.convert(u).bytes;
      for (var j = 0; j < result.length; j++) {
        result[j] ^= u[j];
      }
    }
    return result;
  }

  Uint8List _randomSalt(int length) {
    final rng = _SecureRandom();
    final bytes = Uint8List(length);
    for (var i = 0; i < length; i++) {
      bytes[i] = rng.next();
    }
    return bytes;
  }

  bool _constantTimeEquals(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }
}

/// RNG criptográfico mínimo respaldado por `Random.secure()`.
class _SecureRandom {
  static final _random = Random.secure();

  int next() => _random.nextInt(256);
}
