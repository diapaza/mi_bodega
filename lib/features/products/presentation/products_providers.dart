import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mi_bodega/core/di/app_providers.dart';
import 'package:mi_bodega/features/auth/presentation/session_controller.dart';
import 'package:mi_bodega/features/products/domain/entities/product.dart';

enum ProductViewMode { grid, list }

/// Filtros y ordenamiento de la lista de productos.
class ProductListFilter {
  final String search;
  final int? categoryId;
  final int? brandId;
  final bool onlyActive;
  final ProductSort sort;

  const ProductListFilter({
    this.search = '',
    this.categoryId,
    this.brandId,
    this.onlyActive = true,
    this.sort = ProductSort.nameAsc,
  });

  ProductListFilter copyWith({
    String? search,
    int? Function()? categoryId,
    int? Function()? brandId,
    bool? onlyActive,
    ProductSort? sort,
  }) {
    return ProductListFilter(
      search: search ?? this.search,
      categoryId: categoryId != null ? categoryId() : this.categoryId,
      brandId: brandId != null ? brandId() : this.brandId,
      onlyActive: onlyActive ?? this.onlyActive,
      sort: sort ?? this.sort,
    );
  }
}

final productListFilterProvider =
    StateProvider<ProductListFilter>((_) => const ProductListFilter());

final productViewModeProvider =
    StateProvider<ProductViewMode>((_) => ProductViewMode.grid);

/// Lista reactiva de productos según filtros/orden actuales.
final productsProvider = StreamProvider<List<ProductStock>>((ref) {
  final storeId = ref.watch(sessionControllerProvider).valueOrNull?.store?.id;
  if (storeId == null) return const Stream.empty();
  final f = ref.watch(productListFilterProvider);
  return ref.watch(productRepositoryProvider).watchProducts(
        storeId: storeId,
        search: f.search.isEmpty ? null : f.search,
        categoryId: f.categoryId,
        brandId: f.brandId,
        onlyActive: f.onlyActive,
        sort: f.sort,
      );
});

final productByIdProvider =
    FutureProvider.family<ProductStock?, int>((ref, id) {
  return ref.watch(productRepositoryProvider).productWithStock(id).then(
        (r) => r.orNull,
      );
});

final productConversionsProvider = StreamProvider.family<
    List<ProductUnitConversion>, int>((ref, productId) {
  return ref.watch(productRepositoryProvider).watchConversions(productId);
});
