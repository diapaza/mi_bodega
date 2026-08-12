import 'package:mi_bodega/core/database/app_database.dart' as db;
import 'package:mi_bodega/core/database/daos.dart' as daos;
import 'package:drift/drift.dart';
import 'package:mi_bodega/core/error/abort_transaction.dart';
import 'package:mi_bodega/core/error/failures.dart';
import 'package:mi_bodega/core/error/result.dart';
import 'package:mi_bodega/core/money/money.dart';
import 'package:mi_bodega/features/cash/domain/entities/cash.dart';
import 'package:mi_bodega/features/cash/domain/repositories/cash_repository.dart';
import 'package:mi_bodega/features/sales/domain/entities/sale.dart';
import 'package:mi_bodega/features/store/domain/entities/store.dart';

class DriftCashRepository implements CashRepository {
  final db.AppDatabase database;

  DriftCashRepository(this.database);

  daos.CashDao get _cashDao => database.cashDao;
  daos.AuditDao get _auditDao => database.auditDao;

  /// Umbral por defecto para autorizar diferencias (S/5).
  static const _defaultThreshold = 500;

  @override
  Stream<CashSession?> watchOpenSession(int registerId) {
    return _cashDao.watchOpenSession(registerId).map((s) => s == null ? null : _mapSession(s));
  }

  @override
  Future<Result<CashSession?>> currentOpenSession(int registerId) async {
    try {
      final row = await _cashDao.openSession(registerId);
      return Ok(row == null ? null : _mapSession(row));
    } catch (e) {
      return Err(failureFrom(e));
    }
  }

  @override
  Future<Result<CashSession>> openSession({
    required int registerId,
    required int userId,
    Money openingAmount = const Money.zero(),
  }) async {
    try {
      final session = await database.transaction(() async {
        final existing = await _cashDao.openSession(registerId);
        if (existing != null) {
          throw AbortTransaction(Failure(
            code: FailureCode.cashSessionAlreadyOpen,
            message: 'Ya existe una sesión de caja abierta.',
          ));
        }
        final now = DateTime.now();
        final sessionId = await _cashDao.insertSession(
          db.CashSessionsCompanion.insert(
            registerId: registerId,
            userId: userId,
            openingAmount: Value(openingAmount.cents),
            openingDate: Value(now),
          ),
        );
        await _cashDao.insertMovement(db.CashMovementsCompanion.insert(
          cashSessionId: sessionId,
          movementType: CashMovementType.opening.dbName,
          amount: openingAmount.cents,
          userId: Value(userId),
        ));
        await _auditDao.insertAudit(db.AuditLogsCompanion.insert(
          userId: Value(userId),
          action: 'create',
          entityType: 'cash_session',
          entityId: Value('$sessionId'),
        ));
        final row = await _cashDao.sessionById(sessionId);
        return _mapSession(row!);
      });
      return Ok(session);
    } on AbortTransaction catch (e) {
      return Err(e.failure);
    } catch (e) {
      return Err(failureFrom(e));
    }
  }

  @override
  Future<Result<CashSession>> closeSession({
    required int sessionId,
    required int closedBy,
    required Money countedAmount,
    String? note,
    required bool authorizeDifference,
  }) async {
    try {
      final session = await database.transaction(() async {
        final existing = await _cashDao.sessionById(sessionId);
        if (existing == null || existing.status != 'open') {
          throw AbortTransaction(Failure(
            code: FailureCode.cashSessionClosed,
            message: 'La sesión de caja no está abierta.',
          ));
        }
        final expected = await _cashDao.sessionNet(sessionId);
        final counted = countedAmount.cents;
        final difference = counted - expected;
        final threshold = await _readThreshold();
        if (difference.abs() > threshold && !authorizeDifference) {
          throw AbortTransaction(Failure(
            code: FailureCode.needsAuthorization,
            message: 'La diferencia (${Money(difference).format()}) supera el '
                'umbral permitido. Se requiere autorización del propietario.',
          ));
        }
        final now = DateTime.now();
        await _cashDao.updateSession(db.CashSessionsCompanion(
          id: Value(sessionId),
          expectedAmount: Value(expected),
          countedAmount: Value(counted),
          difference: Value(difference),
          status: const Value('closed'),
          closedBy: Value(closedBy),
          closingDate: Value(now),
          note: note == null ? const Value.absent() : Value(note),
          updatedAt: Value(now),
        ));
        await _cashDao.insertMovement(db.CashMovementsCompanion.insert(
          cashSessionId: sessionId,
          movementType: CashMovementType.closing.dbName,
          amount: 0,
          userId: Value(closedBy),
        ));
        await _auditDao.insertAudit(db.AuditLogsCompanion.insert(
          userId: Value(closedBy),
          action: 'close',
          entityType: 'cash_session',
          entityId: Value('$sessionId'),
          afterJson: Value(
            '{"expected":$expected,"counted":$counted,"difference":$difference}',
          ),
        ));
        if (authorizeDifference) {
          await _auditDao.insertAudit(db.AuditLogsCompanion.insert(
            userId: Value(closedBy),
            action: 'authorize_difference',
            entityType: 'cash_session',
            entityId: Value('$sessionId'),
            afterJson: Value('{"difference":$difference}'),
          ));
        }
        final row = await _cashDao.sessionById(sessionId);
        return _mapSession(row!);
      });
      return Ok(session);
    } on AbortTransaction catch (e) {
      return Err(e.failure);
    } catch (e) {
      return Err(failureFrom(e));
    }
  }

  @override
  Future<Result<CashMovement>> addManualMovement({
    required int sessionId,
    required CashMovementType type,
    required Money amount,
    int? userId,
    String? note,
  }) async {
    try {
      final movement = await database.transaction(() async {
        if (type == CashMovementType.sale ||
            type == CashMovementType.opening ||
            type == CashMovementType.closing) {
          throw AbortTransaction(Failure(
            code: FailureCode.validation,
            message: 'Tipo de movimiento no permitido manualmente.',
          ));
        }
        final signed = switch (type) {
          CashMovementType.cashOut => -amount.cents.abs(),
          _ => amount.cents,
        };
        final id = await _cashDao.insertMovement(db.CashMovementsCompanion.insert(
          cashSessionId: sessionId,
          movementType: type.dbName,
          amount: signed,
          userId: userId == null ? const Value.absent() : Value(userId),
          note: note == null ? const Value.absent() : Value(note),
        ));
        await _auditDao.insertAudit(db.AuditLogsCompanion.insert(
          userId: userId == null ? const Value.absent() : Value(userId),
          action: 'cash_movement',
          entityType: 'cash_session',
          entityId: Value('$sessionId'),
          afterJson: Value(
            '{"type":"${type.dbName}","amount":$signed,"note":"${note ?? ''}"}',
          ),
        ));
        return CashMovement(
          id: id,
          cashSessionId: sessionId,
          type: type,
          amount: Money(signed),
          userId: userId,
          note: note,
          createdAt: DateTime.now(),
        );
      });
      return Ok(movement);
    } on AbortTransaction catch (e) {
      return Err(e.failure);
    } catch (e) {
      return Err(failureFrom(e));
    }
  }

  @override
  Future<Result<CashSessionSummary>> sessionSummary(int sessionId) async {
    try {
      final rows = await _cashDao.movementsForSession(sessionId);
      var opening = 0, cashSales = 0, cashIn = 0, cashOut = 0, adjustments = 0;
      for (final m in rows) {
        switch (CashMovementTypeX.fromName(m.movementType)) {
          case CashMovementType.opening:
            opening += m.amount;
          case CashMovementType.sale:
            cashSales += m.amount;
          case CashMovementType.cashIn:
            cashIn += m.amount;
          case CashMovementType.cashOut:
            cashOut += m.amount.abs();
          case CashMovementType.adjustment:
            adjustments += m.amount;
          case CashMovementType.closing:
            break;
        }
      }
      final expected = rows.fold<int>(0, (sum, m) => sum + m.amount);
      return Ok(CashSessionSummary(
        opening: Money(opening),
        cashSales: Money(cashSales),
        cashIn: Money(cashIn),
        cashOut: Money(cashOut),
        adjustments: Money(adjustments),
        expected: Money(expected),
      ));
    } catch (e) {
      return Err(failureFrom(e));
    }
  }

  @override
  Future<Result<Map<PaymentMethod, Money>>> salesByMethod(int sessionId) async {
    try {
      final query = database.select(database.payments).join([
        innerJoin(
          database.sales,
          database.sales.id.equalsExp(database.payments.saleId),
        ),
      ]);
      query.where(database.sales.cashSessionId.equals(sessionId));
      query.groupBy([database.payments.method]);
      query.addColumns([database.payments.amount.sum()]);
      final rows = await query.get();
      final result = <PaymentMethod, Money>{};
      for (final r in rows) {
        final method = PaymentMethodX.fromName(r.readTable(database.payments).method);
        result[method] = Money(r.read(database.payments.amount.sum()) ?? 0);
      }
      return Ok(result);
    } catch (e) {
      return Err(failureFrom(e));
    }
  }

  @override
  Stream<List<Sale>> watchSessionSales(int sessionId) {
    final query = database.select(database.sales)
      ..where((t) => t.cashSessionId.equals(sessionId))
      ..orderBy([(t) => OrderingTerm.desc(t.id)]);
    return query.watch().map((rows) => rows.map(_mapSale).toList());
  }

  @override
  Stream<List<CashMovementWithUser>> watchMovementsForSession(int sessionId) {
    final query = database.select(database.cashMovements).join([
      leftOuterJoin(
        database.users,
        database.users.id.equalsExp(database.cashMovements.userId),
      ),
    ]);
    query.where(database.cashMovements.cashSessionId.equals(sessionId));
    query.orderBy([OrderingTerm.desc(database.cashMovements.id)]);
    return query.watch().map((rows) {
      return rows.map((r) {
        final m = r.readTable(database.cashMovements);
        final user = r.readTableOrNull(database.users);
        return CashMovementWithUser(
          CashMovement(
            id: m.id,
            cashSessionId: m.cashSessionId,
            saleId: m.saleId,
            type: CashMovementTypeX.fromName(m.movementType),
            amount: Money(m.amount),
            method: m.method,
            userId: m.userId,
            note: m.note,
            createdAt: m.createdAt,
          ),
          user?.fullName,
        );
      }).toList();
    });
  }

  @override
  Stream<List<CashSession>> watchSessions(int registerId, {int limit = 50}) {
    return _cashDao.watchSessions(registerId, limit: limit).map((rows) {
      return rows.map(_mapSession).toList();
    });
  }

  Future<int> _readThreshold() async {
    final raw = await database.storeDao
        .getSetting(SettingKeys.cashDifferenceThreshold);
    return int.tryParse(raw ?? '') ?? _defaultThreshold;
  }

  Sale _mapSale(db.Sale s) {
    return Sale(
      id: s.id,
      storeId: s.storeId,
      saleNumber: s.saleNumber,
      cashSessionId: s.cashSessionId,
      customerId: s.customerId,
      userId: s.userId,
      subtotal: Money(s.subtotal),
      discount: Money(s.discount),
      total: Money(s.total),
      paymentMethod: PaymentMethodX.fromName(s.paymentMethod),
      amountReceived: s.amountReceived == null ? null : Money(s.amountReceived!),
      changeDue: s.changeDue == null ? null : Money(s.changeDue!),
      status: s.status == 'cancelled' ? SaleStatus.cancelled : SaleStatus.completed,
      cancelReason: s.cancelReason,
      saleDate: s.saleDate,
      note: s.note,
      createdAt: s.createdAt,
      updatedAt: s.updatedAt,
    );
  }

  CashSession _mapSession(db.CashSession s) {
    return CashSession(
      id: s.id,
      registerId: s.registerId,
      userId: s.userId,
      openingAmount: Money(s.openingAmount),
      openingDate: s.openingDate,
      expectedAmount: s.expectedAmount == null ? null : Money(s.expectedAmount!),
      countedAmount: s.countedAmount == null ? null : Money(s.countedAmount!),
      difference: s.difference == null ? null : Money(s.difference!),
      status: s.status,
      closedBy: s.closedBy,
      closingDate: s.closingDate,
      note: s.note,
      createdAt: s.createdAt,
      updatedAt: s.updatedAt,
    );
  }
}
