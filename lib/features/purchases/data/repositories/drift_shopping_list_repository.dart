import 'package:drift/drift.dart';

import 'package:mi_bodega/core/database/app_database.dart';
import 'package:mi_bodega/core/error/result.dart';
import 'package:mi_bodega/core/money/money.dart';
import 'package:mi_bodega/features/purchases/domain/entities/shopping_list.dart'
    as domain;
import 'package:mi_bodega/features/purchases/domain/repositories/shopping_list_repository.dart';
import 'package:mi_bodega/features/products/domain/entities/product.dart'
    as product;

class DriftShoppingListRepository implements ShoppingListRepository {
  final AppDatabase _db;

  DriftShoppingListRepository(this._db);

  @override
  Stream<List<ShoppingListItemWithProduct>> watchItems(int storeId) {
    return _db.shoppingListDao.watchItems(storeId).map((rows) {
      return rows.map((r) {
        final itemRow = r.readTable(_db.shoppingListItems);
        final productRow = r.readTableOrNull(_db.products);
        final inventoryRow = r.readTableOrNull(_db.inventory);

        final productEntity = product.Product(
          id: productRow?.id,
          storeId: productRow?.storeId ?? storeId,
          categoryId: productRow?.categoryId,
          brandId: productRow?.brandId,
          baseUnitId: productRow?.baseUnitId ?? 0,
          purchaseUnitId: productRow?.purchaseUnitId,
          saleUnitsPerPurchaseUnit: productRow?.saleUnitsPerPurchaseUnit ?? 1,
          sku: productRow?.sku,
          barcode: productRow?.barcode,
          name: productRow?.name ?? '',
          description: productRow?.description,
          purchasePrice: Money(productRow?.purchasePrice ?? 0),
          salePrice: Money(productRow?.salePrice ?? 0),
          costPrice: Money(productRow?.costPrice ?? 0),
          stockMin: productRow?.stockMin ?? 0,
          stockMax: productRow?.stockMax,
          photoPath: productRow?.photoPath,
          active: productRow?.active ?? true,
          isFavorite: productRow?.isFavorite ?? false,
          createdAt: productRow?.createdAt ?? DateTime.now(),
          updatedAt: productRow?.updatedAt ?? DateTime.now(),
        );

        final stock = inventoryRow?.quantity ?? 0;

        final item = domain.ShoppingListItem(
          id: itemRow.id,
          storeId: itemRow.storeId,
          productId: itemRow.productId,
          quantity: itemRow.quantity,
          photoPath: itemRow.photoPath,
          notes: itemRow.notes,
          createdAt: itemRow.createdAt,
          updatedAt: itemRow.updatedAt,
        );

        return ShoppingListItemWithProduct(
            item, product.ProductStock(productEntity, stock));
      }).toList();
    });
  }

  @override
  Future<Result<void>> addItem(domain.ShoppingListItem item) async {
    try {
      await _db.shoppingListDao.addItem(
        ShoppingListItemsCompanion(
          storeId: Value(item.storeId),
          productId: Value(item.productId),
          quantity: Value.absentIfNull(item.quantity),
          photoPath: Value.absentIfNull(item.photoPath),
          notes: Value.absentIfNull(item.notes),
        ),
      );
      return const Ok(null);
    } catch (e) {
      return Err(Failure(
          code: FailureCode.unexpected, message: 'Error al agregar: $e'));
    }
  }

  @override
  Future<Result<void>> updateItem(domain.ShoppingListItem item) async {
    try {
      await _db.shoppingListDao.updateItem(
        ShoppingListItemsCompanion(
          id: Value(item.id!),
          storeId: Value(item.storeId),
          productId: Value(item.productId),
          quantity: Value.absentIfNull(item.quantity),
          photoPath: Value.absentIfNull(item.photoPath),
          notes: Value.absentIfNull(item.notes),
          updatedAt: Value(DateTime.now()),
        ),
      );
      return const Ok(null);
    } catch (e) {
      return Err(Failure(
          code: FailureCode.unexpected, message: 'Error al actualizar: $e'));
    }
  }

  @override
  Future<Result<void>> removeItem(int id) async {
    try {
      await _db.shoppingListDao.removeItem(id);
      return const Ok(null);
    } catch (e) {
      return Err(Failure(
          code: FailureCode.unexpected, message: 'Error al eliminar: $e'));
    }
  }

  @override
  Future<Result<void>> removeByProductId(int storeId, int productId) async {
    try {
      await _db.shoppingListDao.removeByProductId(storeId, productId);
      return const Ok(null);
    } catch (e) {
      return Err(Failure(
          code: FailureCode.unexpected, message: 'Error al eliminar: $e'));
    }
  }
}
