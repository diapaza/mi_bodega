import 'package:mi_bodega/core/error/result.dart';
import 'package:mi_bodega/core/money/money.dart';
import 'package:mi_bodega/features/cash/domain/entities/cash.dart';
import 'package:mi_bodega/features/sales/domain/entities/sale.dart';

/// Contrato de caja.
abstract interface class CashRepository {
  Stream<CashSession?> watchOpenSession(int registerId);

  Future<Result<CashSession?>> currentOpenSession(int registerId);

  /// Abre una sesión (una abierta a la vez por caja). Transacción atómica.
  Future<Result<CashSession>> openSession({
    required int registerId,
    required int userId,
    Money openingAmount,
  });

  /// Cierra la sesión calculando esperado y diferencia. Transacción atómica.
  ///
  /// Si `|diferencia|` supera el umbral configurado, exige [authorizeDifference].
  Future<Result<CashSession>> closeSession({
    required int sessionId,
    required int closedBy,
    required Money countedAmount,
    String? note,
    required bool authorizeDifference,
  });

  /// Registra un ingreso/egreso manual de efectivo. Transacción atómica.
  Future<Result<CashMovement>> addManualMovement({
    required int sessionId,
    required CashMovementType type,
    required Money amount,
    int? userId,
    String? note,
  });

  /// Resumen del turno (apertura, ventas efectivo, ingresos, retiros, esperado).
  Future<Result<CashSessionSummary>> sessionSummary(int sessionId);

  /// Resumen del turno como stream (se actualiza al agregar movimientos).
  Stream<CashSessionSummary> watchSessionSummary(int sessionId);

  /// Desglose de las ventas del turno por método de pago.
  Future<Result<Map<PaymentMethod, Money>>> salesByMethod(int sessionId);

  /// Ventas registradas durante el turno.
  Stream<List<Sale>> watchSessionSales(int sessionId);

  /// Movimientos del turno con el usuario responsable.
  Stream<List<CashMovementWithUser>> watchMovementsForSession(int sessionId);

  Stream<List<CashSession>> watchSessions(int registerId, {int limit = 50});
}
