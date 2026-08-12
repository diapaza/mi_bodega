import 'package:mi_bodega/core/error/result.dart';
import 'package:mi_bodega/features/sales/domain/entities/sale.dart';

/// Contrato de ventas.
abstract interface class SaleRepository {
  Stream<List<Sale>> watchSales({required int storeId, int limit = 50});

  /// Ventas con filtros (fecha, vendedor, método, búsqueda por nº/cliente).
  Stream<List<Sale>> watchSalesFiltered({
    required int storeId,
    DateTime? from,
    DateTime? to,
    int? userId,
    String? method,
    String? search,
  });

  Stream<List<Sale>> watchSalesByDate(
    int storeId,
    DateTime from,
    DateTime to,
  );

  Future<Result<SaleDetail?>> saleByNumber(int storeId, String saleNumber);

  Future<Result<SaleDetail?>> saleById(int id);

  /// Registra una venta de forma ATÓMICA:
  /// venta + items + descontar stock/movimientos + pago + caja + auditoría.
  Future<Result<SaleDetail>> registerSale(SaleRequest request);

  /// Anula una venta de forma ATÓMICA: marca `cancelled` con el [reason]
  /// (obligatorio), repone stock con movimientos, revierte efectivo de caja
  /// y audita.
  Future<Result<SaleDetail>> cancelSale(
    int saleId,
    int userId, {
    required String reason,
  });

  /// Productos más vendidos por cantidad (para "frecuentes" del POS).
  Future<Result<List<TopSoldProduct>>> topSoldProducts(
    int storeId, {
    int limit = 8,
  });
}
