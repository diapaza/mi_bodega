import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mi_bodega/core/di/app_providers.dart';
import 'package:mi_bodega/features/auth/presentation/session_controller.dart';
import 'package:mi_bodega/features/cash/domain/entities/cash.dart';
import 'package:mi_bodega/features/products/domain/entities/product.dart';
import 'package:mi_bodega/features/sales/domain/entities/sale.dart';

/// Texto de búsqueda del POS (con debounce en la pantalla).
final posSearchProvider = StateProvider<String>((_) => '');

/// Productos activos visibles en el POS según la búsqueda.
final posProductsProvider = StreamProvider<List<ProductStock>>((ref) {
  final storeId = ref.watch(sessionControllerProvider).valueOrNull?.store?.id;
  if (storeId == null) return const Stream.empty();
  final search = ref.watch(posSearchProvider);
  return ref.watch(productRepositoryProvider).watchProducts(
        storeId: storeId,
        search: search.isEmpty ? null : search,
      );
});

/// Productos favoritos (para la fila de frecuentes).
final favoriteProductsProvider = StreamProvider<List<ProductStock>>((ref) {
  final storeId = ref.watch(sessionControllerProvider).valueOrNull?.store?.id;
  if (storeId == null) return const Stream.empty();
  return ref.watch(productRepositoryProvider).watchProducts(
        storeId: storeId,
        search: null,
      ).map((list) => list.where((p) => p.product.isFavorite).toList());
});

/// Productos más vendidos (para la fila de frecuentes).
final topSoldProvider =
    FutureProvider<List<TopSoldProduct>>((ref) async {
  final storeId = ref.watch(sessionControllerProvider).valueOrNull?.store?.id;
  if (storeId == null) return const [];
  return (await ref.watch(saleRepositoryProvider).topSoldProducts(storeId))
      .orNull ?? const [];
});

/// Caja registradora por defecto.
final defaultRegisterProvider = FutureProvider<int?>((ref) async {
  return (await ref.watch(databaseProvider).cashDao.defaultRegister())?.id;
});

/// Sesión de caja abierta (el POS requiere una para vender).
final openCashSessionProvider = StreamProvider<CashSession?>((ref) {
  final registerId = ref.watch(defaultRegisterProvider).valueOrNull;
  if (registerId == null) return Stream.value(null);
  return ref.watch(cashRepositoryProvider).watchOpenSession(registerId);
});
