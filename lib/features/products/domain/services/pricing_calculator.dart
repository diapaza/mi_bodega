/// Cálculos de precios y conversión de unidades.
///
/// Todo el dinero se maneja en [Money] (céntimos). Los porcentajes se
/// expresan como fracción (0.25 = 25%).
library;

import 'package:mi_bodega/core/money/money.dart';

class PricingResult {
  final Money unitCost;
  final Money totalCost;
  final Money potentialRevenue;
  final Money grossProfit;

  const PricingResult({
    required this.unitCost,
    required this.totalCost,
    required this.potentialRevenue,
    required this.grossProfit,
  });

  /// Margen bruto = ganancia / ingreso (0..1).
  double get margin =>
      potentialRevenue.isZero ? 0 : grossProfit.cents / potentialRevenue.cents;

  /// Markup = ganancia / costo total (0..∞).
  double get markup =>
      totalCost.isZero ? 0 : grossProfit.cents / totalCost.cents;

  String get marginPercent => _pct(margin);

  String get markupPercent => _pct(markup);

  static String _pct(double v) => '${(v * 100).toStringAsFixed(1)}%';
}

/// Servicio puro de cálculo de precios.
class PricingCalculator {
  const PricingCalculator();

  /// Costo por unidad base cuando se compra un paquete a [packagePrice]
  /// que contiene [unitsInPackage] unidades.
  Money costPerUnit(Money packagePrice, double unitsInPackage) {
    if (unitsInPackage <= 0) return packagePrice;
    return Money((packagePrice.cents / unitsInPackage).round());
  }

  /// Ingreso potencial si se venden todas las [unitsInPackage] a [unitSalePrice].
  Money potentialRevenue(double unitsInPackage, Money unitSalePrice) {
    return Money((unitSalePrice.cents * unitsInPackage).round());
  }

  /// Análisis completo de un paquete (p. ej. caja = 24 uds).
  PricingResult analyzePackage({
    required Money packageCost,
    required double unitsInPackage,
    required Money unitSalePrice,
  }) {
    final unitCost = costPerUnit(packageCost, unitsInPackage);
    final revenue = potentialRevenue(unitsInPackage, unitSalePrice);
    return PricingResult(
      unitCost: unitCost,
      totalCost: packageCost,
      potentialRevenue: revenue,
      grossProfit: revenue - packageCost,
    );
  }

  /// Precio de venta recomendado a partir de un costo y un margen objetivo
  /// (fracción). precio = costo / (1 - margen).
  Money recommendedFromMargin(Money cost, double targetMargin) {
    final denom = 1 - targetMargin;
    if (denom <= 0) return cost;
    return Money((cost.cents / denom).round());
  }

  /// Precio de venta recomendado a partir de un costo y un markup objetivo
  /// (fracción). precio = costo × (1 + markup).
  Money recommendedFromMarkup(Money cost, double targetMarkup) {
    return Money((cost.cents * (1 + targetMarkup)).round());
  }
}
