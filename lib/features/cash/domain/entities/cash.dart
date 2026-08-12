/// Entidades de caja: cajas, sesiones y movimientos de efectivo.
library;

import 'package:mi_bodega/core/money/money.dart';

class CashSession {
  final int? id;
  final int registerId;
  final int userId;
  final Money openingAmount;
  final DateTime openingDate;
  final Money? expectedAmount;
  final Money? countedAmount;
  final Money? difference;
  final String status;
  final int? closedBy;
  final DateTime? closingDate;
  final String? note;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CashSession({
    this.id,
    required this.registerId,
    required this.userId,
    this.openingAmount = const Money.zero(),
    required this.openingDate,
    this.expectedAmount,
    this.countedAmount,
    this.difference,
    this.status = 'open',
    this.closedBy,
    this.closingDate,
    this.note,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isOpen => status == 'open';
}

enum CashMovementType { opening, sale, cashIn, cashOut, adjustment, closing }

class CashMovement {
  final int? id;
  final int cashSessionId;
  final int? saleId;
  final CashMovementType type;
  final Money amount;
  final String? method;
  final int? userId;
  final String? note;
  final DateTime createdAt;

  const CashMovement({
    this.id,
    required this.cashSessionId,
    this.saleId,
    required this.type,
    required this.amount,
    this.method,
    this.userId,
    this.note,
    required this.createdAt,
  });
}

extension CashMovementTypeX on CashMovementType {
  String get dbName {
    return switch (this) {
      CashMovementType.opening => 'opening',
      CashMovementType.sale => 'sale',
      CashMovementType.cashIn => 'cash_in',
      CashMovementType.cashOut => 'cash_out',
      CashMovementType.adjustment => 'adjustment',
      CashMovementType.closing => 'closing',
    };
  }

  /// Etiqueta legible para la UI.
  String get label {
    return switch (this) {
      CashMovementType.opening => 'Apertura',
      CashMovementType.sale => 'Venta en efectivo',
      CashMovementType.cashIn => 'Ingreso manual',
      CashMovementType.cashOut => 'Retiro',
      CashMovementType.adjustment => 'Ajuste',
      CashMovementType.closing => 'Cierre',
    };
  }

  static CashMovementType fromName(String name) {
    return switch (name) {
      'sale' => CashMovementType.sale,
      'cash_in' => CashMovementType.cashIn,
      'cash_out' => CashMovementType.cashOut,
      'adjustment' => CashMovementType.adjustment,
      'closing' => CashMovementType.closing,
      _ => CashMovementType.opening,
    };
  }
}

/// Resumen de una sesión de caja para el cierre.
class CashSessionSummary {
  final Money opening;
  final Money cashSales;
  final Money cashIn;
  final Money cashOut;
  final Money adjustments;
  final Money expected;

  const CashSessionSummary({
    required this.opening,
    required this.cashSales,
    required this.cashIn,
    required this.cashOut,
    required this.adjustments,
    required this.expected,
  });
}

/// Movimiento de caja junto con el usuario que lo realizó.
class CashMovementWithUser {
  final CashMovement movement;
  final String? userName;

  const CashMovementWithUser(this.movement, this.userName);
}
