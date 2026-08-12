import 'package:mi_bodega/core/money/money.dart';
import 'package:mi_bodega/features/products/domain/entities/product.dart';
import 'package:mi_bodega/features/sales/domain/entities/sale.dart';

/// Resumen de ventas de un periodo.
///
/// INGRESO ≠ GANANCIA: [revenue] son las ventas completadas; [cogs] es el
/// costo de lo vendido (snapshot por línea); [grossProfit] = revenue − cogs.
class SalesSummary {
  final Money revenue;
  final int count;
  final Money cogs;
  final Money grossProfit;
  final double margin;
  final Map<PaymentMethod, Money> byMethod;
  final Map<int, Money> byUser;

  const SalesSummary({
    required this.revenue,
    required this.count,
    required this.cogs,
    required this.grossProfit,
    required this.margin,
    required this.byMethod,
    required this.byUser,
  });
}

/// Estadísticas de un producto en el periodo.
class ProductSalesStats {
  final ProductStock productStock;
  final double quantity;
  final Money revenue;
  final Money cost;
  final Money profit;

  const ProductSalesStats({
    required this.productStock,
    required this.quantity,
    required this.revenue,
    required this.cost,
    required this.profit,
  });
}

/// Punto de la serie diaria de ventas.
class DailySalesPoint {
  final DateTime day;
  final Money revenue;
  final int count;

  const DailySalesPoint({
    required this.day,
    required this.revenue,
    required this.count,
  });
}
