import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';

/// Cifrado de respaldos con AES-256-GCM.
///
/// La clave se deriva de la passphrase del propietario con PBKDF2-HMAC-SHA256
/// y un salt aleatorio por respaldo. Formato del blob:
/// `[salt(16)][nonce(12)][cipherText][mac(16)]`.
class BackupEncryption {
  static const _saltLength = 16;
  static const _nonceLength = 12;
  static const _macLength = 16;

  static Future<List<int>> encryptBytes(List<int> data, String passphrase) async {
    final salt = _randomBytes(_saltLength);
    final key = await _deriveKey(passphrase, salt);
    final algorithm = AesGcm.with256bits();
    final nonce = algorithm.newNonce();
    final box = await algorithm.encrypt(data, secretKey: key, nonce: nonce);
    return <int>[...salt, ...nonce, ...box.cipherText, ...box.mac.bytes];
  }

  /// Descifra; devuelve `null` si la passphrase es incorrecta o el blob está
  /// corrupto (la verificación del MAC lo detecta).
  static Future<List<int>?> decryptBytes(List<int> data, String passphrase) async {
    if (data.length <= _saltLength + _nonceLength + _macLength) return null;
    final salt = data.sublist(0, _saltLength);
    final nonce = data.sublist(_saltLength, _saltLength + _nonceLength);
    final mac = data.sublist(data.length - _macLength);
    final cipher = data.sublist(_saltLength + _nonceLength, data.length - _macLength);
    final key = await _deriveKey(passphrase, salt);
    try {
      return await AesGcm.with256bits().decrypt(
        SecretBox(cipher, nonce: nonce, mac: Mac(mac)),
        secretKey: key,
      );
    } catch (_) {
      return null;
    }
  }

  static Future<SecretKey> _deriveKey(String passphrase, List<int> salt) {
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: 60000,
      bits: 256,
    );
    return pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(passphrase)),
      nonce: salt,
    );
  }

  static List<int> _randomBytes(int n) =>
      List<int>.generate(n, (_) => Random.secure().nextInt(256));
}
