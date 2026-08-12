import 'package:mi_bodega/core/error/result.dart';
import 'package:mi_bodega/features/products/domain/entities/product.dart';

/// Contrato del catálogo de productos.
abstract interface class ProductRepository {
  Stream<List<ProductStock>> watchProducts({
    required int storeId,
    bool onlyActive = true,
    String? search,
    int? categoryId,
    int? brandId,
    ProductSort? sort,
  });

  Future<Result<List<ProductStock>>> searchProducts({
    required int storeId,
    required String search,
    bool onlyActive = true,
    int? categoryId,
    int? brandId,
  });

  Future<Result<ProductStock?>> productWithStock(int id);

  /// Crea el producto, sus conversiones y el stock inicial (transacción).
  Future<Result<Product>> createProduct(
    ProductDraft draft, {
    List<ProductUnitConversion> conversions = const [],
  });

  /// Actualiza datos del producto (sin tocar stock ni precios de coste).
  Future<Result<Product>> updateProduct(
    int id,
    ProductDraft draft, {
    List<ProductUnitConversion> conversions = const [],
  });

  Future<Result<void>> setActive(int id, bool active);

  Future<Result<void>> setFavorite(int id, bool favorite);

  /// `true` si el producto no tiene movimientos, ventas ni compras y por lo
  /// tanto puede eliminarse físicamente sin romper la trazabilidad.
  Future<Result<bool>> canHardDelete(int id);

  /// Elimina el producto: físicamente si no tiene historial, o lo desactiva
  /// (soft delete) en caso contrario.
  Future<Result<DeleteProductResult>> deleteProduct(int id);

  Stream<List<ProductUnitConversion>> watchConversions(int productId);
}
