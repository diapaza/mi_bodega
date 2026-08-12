import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mi_bodega/core/di/app_providers.dart';
import 'package:mi_bodega/features/auth/presentation/session_controller.dart';
import 'package:mi_bodega/features/customers/domain/entities/customer.dart';
import 'package:mi_bodega/features/sales/domain/entities/sale.dart';

final customersSearchProvider = StateProvider<String>((_) => '');

final customersProvider = FutureProvider<List<Customer>>((ref) {
  final storeId = ref.watch(sessionControllerProvider).valueOrNull?.store?.id;
  if (storeId == null) return Future.value(const []);
  final query = ref.watch(customersSearchProvider);
  return ref
      .watch(customerRepositoryProvider)
      .search(query, storeId)
      .then((r) => r.orNull ?? const []);
});

final customerDetailProvider =
    FutureProvider.family<Customer?, int>((ref, id) {
  return ref.watch(customerRepositoryProvider).customerById(id).then((r) => r.orNull);
});

final customerStatsProvider =
    FutureProvider.family<CustomerStats?, int>((ref, id) {
  return ref
      .watch(customerRepositoryProvider)
      .customerStats(id)
      .then((r) => r.orNull);
});

final customerSalesProvider =
    StreamProvider.family<List<Sale>, int>((ref, id) {
  return ref.watch(customerRepositoryProvider).watchCustomerSales(id);
});
