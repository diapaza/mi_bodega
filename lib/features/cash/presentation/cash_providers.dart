import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mi_bodega/core/di/app_providers.dart';
import 'package:mi_bodega/core/money/money.dart';
import 'package:mi_bodega/features/cash/domain/entities/cash.dart';
import 'package:mi_bodega/features/pos/presentation/pos_providers.dart';
import 'package:mi_bodega/features/sales/domain/entities/sale.dart';
import 'package:mi_bodega/features/store/domain/entities/store.dart';

/// Umbral de diferencia que exige autorización al cerrar (default S/5).
final cashThresholdProvider = FutureProvider<int>((ref) async {
  final raw =
      await ref.read(storeRepositoryProvider).getSetting(SettingKeys.cashDifferenceThreshold);
  return int.tryParse(raw.orNull ?? '') ?? 500;
});

final cashSessionSummaryProvider =
    StreamProvider<CashSessionSummary?>((ref) {
  final sessionId = ref.watch(openCashSessionProvider).valueOrNull?.id;
  if (sessionId == null) return Stream.value(null);
  return ref
      .watch(cashRepositoryProvider)
      .watchSessionSummary(sessionId);
});

final sessionMovementsProvider =
    StreamProvider<List<CashMovementWithUser>>((ref) {
  final sessionId = ref.watch(openCashSessionProvider).valueOrNull?.id;
  if (sessionId == null) return const Stream.empty();
  return ref
      .watch(cashRepositoryProvider)
      .watchMovementsForSession(sessionId);
});

final sessionSalesProvider = StreamProvider<List<Sale>>((ref) {
  final sessionId = ref.watch(openCashSessionProvider).valueOrNull?.id;
  if (sessionId == null) return const Stream.empty();
  return ref.watch(cashRepositoryProvider).watchSessionSales(sessionId);
});

final salesByMethodProvider = FutureProvider<Map<PaymentMethod, Money>>((ref) {
  final sessionId = ref.watch(openCashSessionProvider).valueOrNull?.id;
  if (sessionId == null) return Future.value(<PaymentMethod, Money>{});
  return ref
      .watch(cashRepositoryProvider)
      .salesByMethod(sessionId)
      .then((r) => r.orNull ?? {});
});

/// Historial de turnos de la caja principal.
final sessionHistoryProvider = StreamProvider<List<CashSession>>((ref) {
  final registerId = ref.watch(defaultRegisterProvider).valueOrNull;
  if (registerId == null) return const Stream.empty();
  return ref.watch(cashRepositoryProvider).watchSessions(registerId);
});
