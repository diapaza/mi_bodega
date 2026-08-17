import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mi_bodega/core/di/app_providers.dart';
import 'package:mi_bodega/features/auth/presentation/session_controller.dart';
import 'package:mi_bodega/features/reports/domain/entities/report.dart';
import 'package:mi_bodega/features/sales/domain/entities/sale.dart';

enum ReportPeriod { today, yesterday, last7, thisMonth }

final reportPeriodProvider =
    StateProvider<ReportPeriod>((_) => ReportPeriod.today);

/// Contador que se incrementa después de cada venta para refrescar los providers.
final saleRefreshProvider = StateProvider<int>((_) => 0);

(DateTime?, DateTime?) _range(ReportPeriod period, DateTime now) {
  final startOfDay = DateTime(now.year, now.month, now.day);
  return switch (period) {
    ReportPeriod.today => (startOfDay, startOfDay.add(const Duration(days: 1))),
    ReportPeriod.yesterday => (
        startOfDay.subtract(const Duration(days: 1)),
        startOfDay,
      ),
    ReportPeriod.last7 => (
        startOfDay.subtract(const Duration(days: 7)),
        startOfDay.add(const Duration(days: 1)),
      ),
    ReportPeriod.thisMonth => (
        DateTime(now.year, now.month, 1),
        DateTime(now.year, now.month + 1, 1),
      ),
  };
}

final reportSummaryProvider = FutureProvider<SalesSummary?>((ref) {
  ref.watch(saleRefreshProvider); // Se re-ejecuta al crear venta
  final storeId = ref.watch(sessionControllerProvider).valueOrNull?.store?.id;
  if (storeId == null) return Future.value(null);
  final (from, to) = _range(ref.watch(reportPeriodProvider), DateTime.now());
  return ref
      .watch(reportsRepositoryProvider)
      .summary(storeId: storeId, from: from, to: to)
      .then((r) => r.orNull);
});

final reportTopProductsProvider = FutureProvider<List<ProductSalesStats>>((ref) {
  ref.watch(saleRefreshProvider); // Se re-ejecuta al crear venta
  final storeId = ref.watch(sessionControllerProvider).valueOrNull?.store?.id;
  if (storeId == null) return Future.value(const []);
  final (from, to) = _range(ref.watch(reportPeriodProvider), DateTime.now());
  return ref
      .watch(reportsRepositoryProvider)
      .topProducts(storeId: storeId, from: from, to: to, limit: 10)
      .then((r) => r.orNull ?? const []);
});

final reportDailyProvider = FutureProvider<List<DailySalesPoint>>((ref) {
  ref.watch(saleRefreshProvider); // Se re-ejecuta al crear venta
  final storeId = ref.watch(sessionControllerProvider).valueOrNull?.store?.id;
  if (storeId == null) return Future.value(const []);
  final (from, to) = _range(ReportPeriod.last7, DateTime.now());
  return ref
      .watch(reportsRepositoryProvider)
      .dailySeries(storeId: storeId, from: from, to: to)
      .then((r) => r.orNull ?? const []);
});

/// Dashboard: ventas del día (hoy).
final todaySummaryProvider = FutureProvider<SalesSummary?>((ref) {
  ref.watch(saleRefreshProvider); // Se re-ejecuta al crear venta
  final storeId = ref.watch(sessionControllerProvider).valueOrNull?.store?.id;
  if (storeId == null) return Future.value(null);
  final (from, to) = _range(ReportPeriod.today, DateTime.now());
  return ref
      .watch(reportsRepositoryProvider)
      .summary(storeId: storeId, from: from, to: to)
      .then((r) => r.orNull);
});

/// Dashboard: ventas del mes.
final monthSummaryProvider = FutureProvider<SalesSummary?>((ref) {
  ref.watch(saleRefreshProvider); // Se re-ejecuta al crear venta
  final storeId = ref.watch(sessionControllerProvider).valueOrNull?.store?.id;
  if (storeId == null) return Future.value(null);
  final (from, to) = _range(ReportPeriod.thisMonth, DateTime.now());
  return ref
      .watch(reportsRepositoryProvider)
      .summary(storeId: storeId, from: from, to: to)
      .then((r) => r.orNull);
});

/// Actividad reciente (últimas ventas).
final recentSalesProvider = StreamProvider<List<Sale>>((ref) {
  final storeId = ref.watch(sessionControllerProvider).valueOrNull?.store?.id;
  if (storeId == null) return const Stream.empty();
  return ref.watch(saleRepositoryProvider).watchSales(storeId: storeId, limit: 8);
});
