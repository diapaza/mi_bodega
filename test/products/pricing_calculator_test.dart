import 'package:flutter_test/flutter_test.dart';
import 'package:mi_bodega/core/money/money.dart';
import 'package:mi_bodega/features/products/domain/services/pricing_calculator.dart';

void main() {
  const calculator = PricingCalculator();

  group('Análisis de paquete (1 caja = 24 uds, compra S/57, venta S/3.50)', () {
    test('costo unitario, ingreso, ganancia, margen y markup', () {
      final result = calculator.analyzePackage(
        packageCost: const Money(5700),
        unitsInPackage: 24,
        unitSalePrice: const Money(350),
      );
      expect(result.unitCost.cents, 238); // 237.5 → 238 (redondeo half-up)
      expect(result.unitCost.format(), 'S/ 2.38');
      expect(result.potentialRevenue.cents, 8400);
      expect(result.potentialRevenue.format(), 'S/ 84.00');
      expect(result.grossProfit.cents, 2700); // 8400 - 5700
      expect(result.margin, closeTo(0.3214, 0.001));
      expect(result.markup, closeTo(0.4737, 0.001));
      expect(result.marginPercent, '32.1%');
      expect(result.markupPercent, '47.4%');
    });

    test('división exacta', () {
      expect(calculator.costPerUnit(const Money(300), 3).cents, 100);
    });

    test('costo por unidad con factor inválido no divide por cero', () {
      expect(calculator.costPerUnit(const Money(500), 0).cents, 500);
    });
  });

  group('Precio recomendado', () {
    test('por margen objetivo', () {
      final p = calculator.recommendedFromMargin(const Money(238), 0.30);
      expect(p.cents, 340); // 238 / 0.7 = 340.0
    });

    test('por markup objetivo', () {
      final p = calculator.recommendedFromMarkup(const Money(200), 0.75);
      expect(p.cents, 350);
    });

    test('margen objetivo inválido devuelve el costo', () {
      expect(calculator.recommendedFromMargin(const Money(100), 1.0).cents, 100);
    });
  });

  test('ingreso potencial', () {
    expect(calculator.potentialRevenue(24, const Money(350)).cents, 8400);
  });
}
