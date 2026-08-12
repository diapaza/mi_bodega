/// Entidades de inventario: saldo y libro mayor de movimientos.
library;

enum MovementType {
  initial,
  purchaseIn,
  saleOut,
  returnIn,
  returnOut,
  adjustment,
  correction,
  loss,
  manualIn,
  manualOut,
}

extension MovementTypeX on MovementType {
  String get dbName {
    return switch (this) {
      MovementType.initial => 'initial',
      MovementType.purchaseIn => 'purchase_in',
      MovementType.saleOut => 'sale_out',
      MovementType.returnIn => 'return_in',
      MovementType.returnOut => 'return_out',
      MovementType.adjustment => 'adjustment',
      MovementType.correction => 'correction',
      MovementType.loss => 'loss',
      MovementType.manualIn => 'manual_in',
      MovementType.manualOut => 'manual_out',
    };
  }

  /// Etiqueta legible para la UI.
  String get label {
    return switch (this) {
      MovementType.initial => 'Stock inicial',
      MovementType.purchaseIn => 'Compra / Abastecimiento',
      MovementType.saleOut => 'Venta',
      MovementType.returnIn => 'Devolución (entrada)',
      MovementType.returnOut => 'Devolución a proveedor',
      MovementType.adjustment => 'Ajuste',
      MovementType.correction => 'Corrección',
      MovementType.loss => 'Merma / Pérdida',
      MovementType.manualIn => 'Entrada manual',
      MovementType.manualOut => 'Salida manual',
    };
  }

  static MovementType fromName(String name) {
    return switch (name) {
      'purchase_in' => MovementType.purchaseIn,
      'sale_out' => MovementType.saleOut,
      'return_in' => MovementType.returnIn,
      'return_out' => MovementType.returnOut,
      'adjustment' => MovementType.adjustment,
      'correction' => MovementType.correction,
      'loss' => MovementType.loss,
      'manual_in' => MovementType.manualIn,
      'manual_out' => MovementType.manualOut,
      _ => MovementType.initial,
    };
  }
}

/// Movimiento de inventario (registro inmutable del libro mayor).
class InventoryMovement {
  final int? id;
  final int productId;
  final MovementType type;
  final double quantity;
  final double beforeQty;
  final double afterQty;
  final int? unitId;
  final String? referenceType;
  final int? referenceId;
  final int? userId;
  final String? note;
  final DateTime createdAt;

  const InventoryMovement({
    this.id,
    required this.productId,
    required this.type,
    required this.quantity,
    required this.beforeQty,
    required this.afterQty,
    this.unitId,
    this.referenceType,
    this.referenceId,
    this.userId,
    this.note,
    required this.createdAt,
  });
}

/// Saldo actual de un producto.
class Stock {
  final int productId;
  final double quantity;

  const Stock(this.productId, this.quantity);
}

/// Movimiento junto con el nombre del usuario y del producto (historial).
class MovementWithUser {
  final InventoryMovement movement;
  final String? userName;
  final String? productName;

  const MovementWithUser(this.movement, this.userName, {this.productName});
}

/// Solicitud de ajuste manual de stock.
class StockAdjustment {
  final int productId;
  final MovementType type;
  final double quantity;
  final String? reason;
  final int? userId;

  const StockAdjustment({
    required this.productId,
    required this.type,
    required this.quantity,
    this.reason,
    this.userId,
  });
}
