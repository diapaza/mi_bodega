import 'package:mi_bodega/core/error/result.dart';
import 'package:mi_bodega/features/purchases/domain/entities/purchase.dart';

/// Contrato de compras/abastecimiento.
abstract interface class PurchaseRepository {
  Stream<List<Purchase>> watchPurchases(int storeId, {int limit = 50});

  Future<Result<Purchase?>> purchaseById(int id);

  Future<Result<List<PurchaseItem>>> itemsForPurchase(int purchaseId);

  /// Registra una compra de forma ATÓMICA:
  /// compra + items + incrementar stock/movimientos + actualizar costo promedio.
  Future<Result<Purchase>> createPurchase(PurchaseRequest request);
}

/// Contrato de proveedores.
abstract interface class SupplierRepository {
  Stream<List<Supplier>> watchSuppliers(int storeId, {bool onlyActive = true});

  Future<Result<Supplier>> createSupplier(Supplier supplier);

  Future<Result<Supplier>> updateSupplier(Supplier supplier);

  Future<Result<void>> setActive(int id, bool active);
}
