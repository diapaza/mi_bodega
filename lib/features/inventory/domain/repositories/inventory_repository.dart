import 'package:mi_bodega/core/error/result.dart';
import 'package:mi_bodega/core/money/money.dart';
import 'package:mi_bodega/features/inventory/domain/entities/inventory.dart';
import 'package:mi_bodega/features/products/domain/entities/product.dart';

/// Contrato del libro mayor de inventario.
abstract interface class InventoryRepository {
  Stream<double> watchStock(int productId);

  Future<Result<double>> stockOf(int productId);

  Stream<List<InventoryMovement>> watchMovements(int productId, {int limit = 100});

  /// Movimientos de un producto con el nombre del usuario (historial).
  Stream<List<MovementWithUser>> watchMovementsWithUser(int productId, {int limit = 100});

  /// Historial global de la tienda con usuario y producto.
  Stream<List<MovementWithUser>> watchMovementsGlobal(int storeId, {int limit = 200});

  Stream<List<ProductStock>> watchLowStock(int storeId);

  Stream<List<ProductStock>> watchOutOfStock(int storeId);

  /// Productos con stock por encima del máximo definido.
  Stream<List<ProductStock>> watchExcessStock(int storeId);

  /// Valor estimado del inventario: Σ stock × costo promedio.
  Stream<double> watchInventoryValue(int storeId);

  Future<Result<double>> inventoryValue(int storeId);

  /// Costo de la última compra por unidad base del producto.
  Future<Result<Money?>> lastPurchaseCost(int productId);

  /// Ajusta stock manualmente (ajuste/corrección/merma). Transacción atómica.
  Future<Result<InventoryMovement>> adjustStock(StockAdjustment adjustment);
}
