import 'package:flutter_test/flutter_test.dart';
import 'package:mi_bodega/core/money/money.dart';

void main() {
  group('Money', () {
    test('representa soles en céntimos sin floats', () {
      const money = Money(350);
      expect(money.toSoles(), 3.5);
      expect(Money.fromSoles(3.5).cents, 350);
    });

    test('suma y resta exactas', () {
      expect((Money(100) + Money(25)).cents, 125);
      expect((Money(100) - Money(25)).cents, 75);
    });

    test('multiplicación por cantidad con redondeo half-up', () {
      expect((Money(57) * 1.5).cents, 86); // 85.5 -> 86
      expect((Money(350) * 24).cents, 8400);
    });

    test('comparación', () {
      expect(Money(100) < Money(200), isTrue);
      expect(Money(200) >= Money(100), isTrue);
      expect(Money.zero().isZero, isTrue);
    });

    test('formato peruano', () {
      expect(Money(0).format(), 'S/ 0.00');
      expect(Money(350).format(), 'S/ 3.50');
      expect(Money(123456).format(), 'S/ 1,234.56');
      expect(Money(-350).format(), '-S/ 3.50');
    });
  });
}
