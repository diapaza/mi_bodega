import 'package:flutter_test/flutter_test.dart';
import 'package:mi_bodega/core/ids/sale_number_generator.dart';

void main() {
  group('SaleNumberGenerator', () {
    const gen = SaleNumberGenerator();

    test('genera el primer número', () {
      expect(gen.next(null), 'V-000001');
      expect(gen.next(''), 'V-000001');
    });

    test('incrementa a partir del último', () {
      expect(gen.next('V-000001'), 'V-000002');
      expect(gen.next('V-000999'), 'V-001000');
    });

    test('soporta prefijos y padding custom', () {
      const custom = SaleNumberGenerator(prefix: 'C-', padding: 4);
      expect(custom.next(null), 'C-0001');
      expect(custom.next('C-0042'), 'C-0043');
    });
  });
}
