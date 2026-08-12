import 'package:flutter_test/flutter_test.dart';
import 'package:mi_bodega/core/security/pin_hasher.dart';

void main() {
  group('PinHasher', () {
    test('genera y verifica un PIN', () {
      const hasher = PinHasher(iterations: 1000);
      final hash = hasher.hash('1234');
      expect(hash, isNot(contains('1234')));
      expect(hash.startsWith('pbkdf2_sha256\$'), isTrue);
      expect(hasher.verify('1234', hash), isTrue);
      expect(hasher.verify('4321', hash), isFalse);
    });

    test('usa salt aleatorio (hashes distintos)', () {
      const hasher = PinHasher(iterations: 1000);
      expect(hasher.hash('1234'), isNot(equals(hasher.hash('1234'))));
    });

    test('rechaza formatos inválidos', () {
      const hasher = PinHasher(iterations: 1000);
      expect(hasher.verify('1234', 'no-es-un-hash'), isFalse);
    });
  });
}
