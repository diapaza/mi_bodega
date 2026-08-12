/// Entidades de ventas.
library;

import 'package:mi_bodega/core/money/money.dart';
import 'package:mi_bodega/features/products/domain/entities/product.dart'
    show ProductStock;

enum PaymentMethod {
  cash,
  yape,
  plin,
  card,
  transfer,
  other,
}

extension PaymentMethodX on PaymentMethod {
  String get dbName {
    return switch (this) {
      PaymentMethod.cash => 'cash',
      PaymentMethod.yape => 'yape',
      PaymentMethod.plin => 'plin',
      PaymentMethod.card => 'card',
      PaymentMethod.transfer => 'transfer',
      PaymentMethod.other => 'other',
    };
  }

  /// Etiqueta legible para la UI.
  String get label {
    return switch (this) {
      PaymentMethod.cash => 'Efectivo',
      PaymentMethod.yape => 'Yape',
      PaymentMethod.plin => 'Plin',
      PaymentMethod.card => 'Tarjeta',
      PaymentMethod.transfer => 'Transferencia',
      PaymentMethod.other => 'Otro',
    };
  }

  static PaymentMethod fromName(String? name) {
    return switch (name) {
      'yape' => PaymentMethod.yape,
      'plin' => PaymentMethod.plin,
      'card' => PaymentMethod.card,
      'transfer' => PaymentMethod.transfer,
      'other' => PaymentMethod.other,
      _ => PaymentMethod.cash,
    };
  }
}

enum SaleStatus { completed, cancelled }

class Sale {
  final int? id;
  final int storeId;
  final String saleNumber;
  final int? cashSessionId;
  final int? customerId;
  final int userId;
  final Money subtotal;
  final Money discount;
  final Money total;
  final PaymentMethod paymentMethod;
  final Money? amountReceived;
  final Money? changeDue;
  final SaleStatus status;
  final String? cancelReason;
  final DateTime saleDate;
  final String? note;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Sale({
    this.id,
    required this.storeId,
    required this.saleNumber,
    this.cashSessionId,
    this.customerId,
    required this.userId,
    this.subtotal = const Money.zero(),
    this.discount = const Money.zero(),
    this.total = const Money.zero(),
    this.paymentMethod = PaymentMethod.cash,
    this.amountReceived,
    this.changeDue,
    this.status = SaleStatus.completed,
    this.cancelReason,
    required this.saleDate,
    this.note,
    required this.createdAt,
    required this.updatedAt,
  });
}

class SaleItem {
  final int? id;
  final int? saleId;
  final int productId;
  final double quantity;
  final int? unitId;
  final Money unitPrice;
  final Money unitCost;
  final double factor;
  final Money subtotal;

  const SaleItem({
    this.id,
    this.saleId,
    required this.productId,
    required this.quantity,
    this.unitId,
    this.unitPrice = const Money.zero(),
    this.unitCost = const Money.zero(),
    this.factor = 1,
    this.subtotal = const Money.zero(),
  });
}

class Payment {
  final int? id;
  final int? saleId;
  final PaymentMethod method;
  final Money amount;
  final String? reference;
  final int? userId;

  const Payment({
    this.id,
    this.saleId,
    required this.method,
    required this.amount,
    this.reference,
    this.userId,
  });
}

/// Línea de venta solicitada por el usuario del POS.
class SaleItemInput {
  final int productId;
  final double quantity;
  final int? unitId;
  final double factor;
  final Money unitPrice;

  const SaleItemInput({
    required this.productId,
    required this.quantity,
    this.unitId,
    this.factor = 1,
    this.unitPrice = const Money.zero(),
  });
}

/// Solicitud de registro de venta (transacción atómica).
class SaleRequest {
  final int storeId;
  final int userId;
  final int? cashSessionId;
  final int? customerId;
  final List<SaleItemInput> items;
  final PaymentMethod paymentMethod;
  final Money discount;
  final Money? amountReceived;
  final String? note;

  const SaleRequest({
    required this.storeId,
    required this.userId,
    this.cashSessionId,
    this.customerId,
    required this.items,
    this.paymentMethod = PaymentMethod.cash,
    this.discount = const Money.zero(),
    this.amountReceived,
    this.note,
  });
}

/// Venta completa con sus líneas y pagos.
class SaleDetail {
  final Sale sale;
  final List<SaleItem> items;
  final List<Payment> payments;

  const SaleDetail(this.sale, this.items, this.payments);
}

/// Producto frecuente por cantidad vendida (para el POS).
class TopSoldProduct {
  final ProductStock productStock;
  final double soldQuantity;

  const TopSoldProduct(this.productStock, this.soldQuantity);
}
