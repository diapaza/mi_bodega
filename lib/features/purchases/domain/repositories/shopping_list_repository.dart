import 'package:mi_bodega/core/error/result.dart';
import 'package:mi_bodega/features/purchases/domain/entities/shopping_list.dart';
import 'package:mi_bodega/features/products/domain/entities/product.dart';

/// Contrato de lista de compras.
abstract interface class ShoppingListRepository {
  Stream<List<ShoppingListItemWithProduct>> watchItems(int storeId);

  Future<Result<void>> addItem(ShoppingListItem item);

  Future<Result<void>> updateItem(ShoppingListItem item);

  Future<Result<void>> removeItem(int id);

  Future<Result<void>> removeByProductId(int storeId, int productId);
}

/// Item de la lista de compras con su producto asociado.
class ShoppingListItemWithProduct {
  final ShoppingListItem item;
  final ProductStock product;

  const ShoppingListItemWithProduct(this.item, this.product);
}
