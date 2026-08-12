import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mi_bodega/core/di/app_providers.dart';
import 'package:mi_bodega/features/auth/presentation/session_controller.dart';
import 'package:mi_bodega/features/sales/domain/entities/sale.dart';

final salesProvider = StreamProvider<List<Sale>>((ref) {
  final storeId = ref.watch(sessionControllerProvider).valueOrNull?.store?.id;
  if (storeId == null) return const Stream.empty();
  return ref.watch(saleRepositoryProvider).watchSales(storeId: storeId);
});

final saleDetailProvider =
    FutureProvider.family<SaleDetail?, int>((ref, id) {
  return ref.watch(saleRepositoryProvider).saleById(id).then((r) => r.orNull);
});

/// Filtros del historial de ventas.
class SalesFilter {
  final DateTime? from;
  final DateTime? to;
  final int? userId;
  final String? method;
  final String? search;

  const SalesFilter({this.from, this.to, this.userId, this.method, this.search});

  SalesFilter copyWith({
    DateTime? Function()? from,
    DateTime? Function()? to,
    int? Function()? userId,
    String? Function()? method,
    String? search,
  }) {
    return SalesFilter(
      from: from != null ? from() : this.from,
      to: to != null ? to() : this.to,
      userId: userId != null ? userId() : this.userId,
      method: method != null ? method() : this.method,
      search: search ?? this.search,
    );
  }
}

final salesFilterProvider =
    StateProvider<SalesFilter>((_) => const SalesFilter());

final filteredSalesProvider = StreamProvider<List<Sale>>((ref) {
  final storeId = ref.watch(sessionControllerProvider).valueOrNull?.store?.id;
  if (storeId == null) return const Stream.empty();
  final f = ref.watch(salesFilterProvider);
  return ref.watch(saleRepositoryProvider).watchSalesFiltered(
        storeId: storeId,
        from: f.from,
        to: f.to,
        userId: f.userId,
        method: f.method,
        search: f.search,
      );
});
