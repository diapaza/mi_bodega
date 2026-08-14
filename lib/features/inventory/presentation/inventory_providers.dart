import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mi_bodega/core/di/app_providers.dart';
import 'package:mi_bodega/features/auth/presentation/session_controller.dart';
import 'package:mi_bodega/features/inventory/domain/entities/inventory.dart';
import 'package:mi_bodega/features/products/domain/entities/product.dart';

enum InventoryFilter { all, low, out, excess }

final inventoryFilterProvider =
    StateProvider<InventoryFilter>((_) => InventoryFilter.all);

final inventorySearchProvider = StateProvider<String>((_) => '');

/// Productos activos de la tienda para la pantalla de inventario.
final inventoryProductsProvider = StreamProvider<List<ProductStock>>((ref) {
  final storeId = ref.watch(sessionControllerProvider).valueOrNull?.store?.id;
  if (storeId == null) return const Stream.empty();
  return ref.watch(productRepositoryProvider).watchProducts(storeId: storeId);
});

/// Valor estimado del inventario (Σ stock × costo).
final inventoryValueProvider = StreamProvider<double>((ref) {
  final storeId = ref.watch(sessionControllerProvider).valueOrNull?.store?.id;
  if (storeId == null) return const Stream.empty();
  return ref.watch(inventoryRepositoryProvider).watchInventoryValue(storeId);
});

final lowStockProvider = StreamProvider<List<ProductStock>>((ref) {
  final storeId = ref.watch(sessionControllerProvider).valueOrNull?.store?.id;
  if (storeId == null) return const Stream.empty();
  return ref.watch(inventoryRepositoryProvider).watchLowStock(storeId);
});

final outOfStockProvider = StreamProvider<List<ProductStock>>((ref) {
  final storeId = ref.watch(sessionControllerProvider).valueOrNull?.store?.id;
  if (storeId == null) return const Stream.empty();
  return ref.watch(inventoryRepositoryProvider).watchOutOfStock(storeId);
});

/// Provider combinado: productos con stock bajo Y agotados en una sola lista.
/// Evita lanzar 2 consultas JOIN simultáneas en RestockScreen.
final lowAndOutOfStockProvider = StreamProvider<List<ProductStock>>((ref) {
  final storeId = ref.watch(sessionControllerProvider).valueOrNull?.store?.id;
  if (storeId == null) return const Stream.empty();

  final controller = StreamController<List<ProductStock>>();

  List<ProductStock>? lowData;
  List<ProductStock>? outData;

  void emitIfReady() {
    if (lowData != null && outData != null && !controller.isClosed) {
      final seen = <int>{};
      final merged = <ProductStock>[];
      for (final p in [...lowData!, ...outData!]) {
        final id = p.product.id;
        if (id != null && seen.add(id)) merged.add(p);
      }
      controller.add(merged);
    }
  }

  // Leer valores actuales para no perder datos ya cargados.
  lowData = ref.read(lowStockProvider).valueOrNull;
  outData = ref.read(outOfStockProvider).valueOrNull;
  emitIfReady();

  // Escuchar cambios futuros.
  final subLow = ref.listen(lowStockProvider, (_, next) {
    lowData = next.valueOrNull;
    emitIfReady();
  });

  final subOut = ref.listen(outOfStockProvider, (_, next) {
    outData = next.valueOrNull;
    emitIfReady();
  });

  ref.onDispose(() {
    subLow.close();
    subOut.close();
    controller.close();
  });

  return controller.stream;
});

final excessStockProvider = StreamProvider<List<ProductStock>>((ref) {
  final storeId = ref.watch(sessionControllerProvider).valueOrNull?.store?.id;
  if (storeId == null) return const Stream.empty();
  return ref.watch(inventoryRepositoryProvider).watchExcessStock(storeId);
});

/// Historial global de movimientos de la tienda.
final movementsGlobalProvider = StreamProvider<List<MovementWithUser>>((ref) {
  final storeId = ref.watch(sessionControllerProvider).valueOrNull?.store?.id;
  if (storeId == null) return const Stream.empty();
  return ref.watch(inventoryRepositoryProvider).watchMovementsGlobal(storeId);
});

/// Historial de movimientos de un producto.
final productMovementsProvider =
    StreamProvider.family<List<MovementWithUser>, int>((ref, productId) {
  return ref.watch(inventoryRepositoryProvider).watchMovementsWithUser(productId);
});

/// Último costo de compra de un producto.
final lastPurchaseCostProvider =
    FutureProvider.family<int?, int>((ref, productId) {
  return ref
      .read(inventoryRepositoryProvider)
      .lastPurchaseCost(productId)
      .then((r) => r.orNull?.cents);
});
