import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mi_bodega/core/di/app_providers.dart';
import 'package:mi_bodega/features/auth/presentation/session_controller.dart';
import 'package:mi_bodega/features/purchases/domain/entities/purchase.dart';
import 'package:mi_bodega/features/purchases/domain/repositories/shopping_list_repository.dart';

final purchasesProvider = StreamProvider<List<Purchase>>((ref) {
  final storeId = ref.watch(sessionControllerProvider).valueOrNull?.store?.id;
  if (storeId == null) return const Stream.empty();
  return ref.watch(purchaseRepositoryProvider).watchPurchases(storeId);
});

final suppliersProvider = StreamProvider<List<Supplier>>((ref) {
  final storeId = ref.watch(sessionControllerProvider).valueOrNull?.store?.id;
  if (storeId == null) return const Stream.empty();
  return ref.watch(supplierRepositoryProvider).watchSuppliers(storeId);
});

final purchaseItemsProvider =
    FutureProvider.family<List<PurchaseItem>, int>((ref, id) {
  return ref
      .watch(purchaseRepositoryProvider)
      .itemsForPurchase(id)
      .then((r) => r.orNull ?? const []);
});

final shoppingListProvider =
    StreamProvider<List<ShoppingListItemWithProduct>>((ref) {
  final storeId = ref.watch(sessionControllerProvider).valueOrNull?.store?.id;
  if (storeId == null) return const Stream.empty();
  return ref.watch(shoppingListRepositoryProvider).watchItems(storeId);
});
