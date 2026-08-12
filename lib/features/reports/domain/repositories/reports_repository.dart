import 'package:mi_bodega/core/error/result.dart';
import 'package:mi_bodega/features/reports/domain/entities/report.dart';

/// Contrato de reportes (solo ventas completadas, por rango de fechas).
abstract interface class ReportsRepository {
  Future<Result<SalesSummary>> summary({
    required int storeId,
    DateTime? from,
    DateTime? to,
  });

  Future<Result<List<ProductSalesStats>>> topProducts({
    required int storeId,
    DateTime? from,
    DateTime? to,
    int limit = 10,
  });

  Future<Result<List<DailySalesPoint>>> dailySeries({
    required int storeId,
    DateTime? from,
    DateTime? to,
  });
}
