import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mi_bodega/core/money/money.dart';
import 'package:mi_bodega/features/products/domain/entities/product.dart';
import 'package:mi_bodega/features/sales/domain/entities/sale.dart';

/// Línea del carrito de venta.
class CartLine {
  final int productId;
  final String name;
  final String? photoPath;
  final int? unitId;
  final double factor;
  final Money unitPrice;
  final double quantity;
  final double availableStock;

  const CartLine({
    required this.productId,
    required this.name,
    this.photoPath,
    this.unitId,
    this.factor = 1,
    this.unitPrice = const Money.zero(),
    this.quantity = 1,
    this.availableStock = 0,
  });

  Money get subtotal => Money((unitPrice.cents * quantity).round());

  CartLine copyWith({
    int? unitId,
    double? factor,
    Money? unitPrice,
    double? quantity,
    double? availableStock,
  }) {
    return CartLine(
      productId: productId,
      name: name,
      photoPath: photoPath,
      unitId: unitId ?? this.unitId,
      factor: factor ?? this.factor,
      unitPrice: unitPrice ?? this.unitPrice,
      quantity: quantity ?? this.quantity,
      availableStock: availableStock ?? this.availableStock,
    );
  }
}

class CartState {
  final List<CartLine> lines;
  final int? customerId;
  final String? customerDni;
  final String? customerName;
  final PaymentMethod method;
  final Money received;
  final Money discount;

  const CartState({
    this.lines = const [],
    this.customerId,
    this.customerDni,
    this.customerName,
    this.method = PaymentMethod.cash,
    this.received = const Money.zero(),
    this.discount = const Money.zero(),
  });

  bool get isEmpty => lines.isEmpty;

  int get count => lines.length;

  double get totalQuantity => lines.fold<double>(0, (s, l) => s + l.quantity);

  Money get subtotal =>
      lines.fold(Money.zero(), (sum, l) => sum + l.subtotal);

  Money get total {
    final t = subtotal - discount;
    return t.isNegative ? Money.zero() : t;
  }

  Money get change => method == PaymentMethod.cash && !received.isNegative
      ? (received - total).isNegative
          ? Money.zero()
          : received - total
      : Money.zero();

  Money get missing => method == PaymentMethod.cash && received < total
      ? total - received
      : Money.zero();

  CartState copyWith({
    List<CartLine>? lines,
    int? Function()? customerId,
    String? Function()? customerDni,
    String? Function()? customerName,
    PaymentMethod? method,
    Money? received,
    Money? discount,
  }) {
    return CartState(
      lines: lines ?? this.lines,
      customerId: customerId != null ? customerId() : this.customerId,
      customerDni: customerDni != null ? customerDni() : this.customerDni,
      customerName: customerName != null ? customerName() : this.customerName,
      method: method ?? this.method,
      received: received ?? this.received,
      discount: discount ?? this.discount,
    );
  }
}

final cartProvider = NotifierProvider<CartController, CartState>(
  CartController.new,
);

/// Estado del carrito del POS.
class CartController extends Notifier<CartState> {
  @override
  CartState build() =>
      const CartState(method: PaymentMethod.cash);

  /// Agrega un producto (o incrementa si ya está). Devuelve `false` si el
  /// stock disponible no permite sumar uno más.
  bool add(ProductStock item) {
    final id = item.product.id!;
    final existing = state.lines.indexWhere((l) => l.productId == id);
    if (existing >= 0) {
      final line = state.lines[existing];
      if (line.quantity + 1 > line.availableStock) return false;
      final lines = [...state.lines];
      lines[existing] = line.copyWith(quantity: line.quantity + 1);
      state = state.copyWith(lines: lines);
      return true;
    }
    if (item.stock < 1) return false;
    final lines = [
      ...state.lines,
      CartLine(
        productId: id,
        name: item.product.name,
        photoPath: item.product.photoPath,
        unitId: item.product.baseUnitId,
        factor: 1,
        unitPrice: item.product.salePrice,
        quantity: 1,
        availableStock: item.stock,
      ),
    ];
    state = state.copyWith(lines: lines);
    return true;
  }

  void increment(int productId) {
    final lines = [...state.lines];
    final idx = lines.indexWhere((l) => l.productId == productId);
    if (idx < 0) return;
    final line = lines[idx];
    final baseQty = (line.quantity + 1) * line.factor;
    if (baseQty > line.availableStock) return;
    lines[idx] = line.copyWith(quantity: line.quantity + 1);
    state = state.copyWith(lines: lines);
  }

  void decrement(int productId) {
    final lines = [...state.lines];
    final idx = lines.indexWhere((l) => l.productId == productId);
    if (idx < 0) return;
    final next = lines[idx].quantity - 1;
    if (next <= 0) {
      lines.removeAt(idx);
    } else {
      lines[idx] = lines[idx].copyWith(quantity: next);
    }
    state = state.copyWith(lines: lines);
  }

  void setQuantity(int productId, double quantity) {
    if (quantity <= 0) {
      remove(productId);
      return;
    }
    final lines = [...state.lines];
    final idx = lines.indexWhere((l) => l.productId == productId);
    if (idx < 0) return;
    final line = lines[idx];
    final maxQty = line.availableStock / line.factor;
    lines[idx] = line.copyWith(
      quantity: quantity > maxQty ? maxQty : quantity,
    );
    state = state.copyWith(lines: lines);
  }

  void setPrice(int productId, Money price) {
    final lines = [...state.lines];
    final idx = lines.indexWhere((l) => l.productId == productId);
    if (idx < 0) return;
    lines[idx] = lines[idx].copyWith(unitPrice: price);
    state = state.copyWith(lines: lines);
  }

  void setUnit(int productId, int? unitId, double factor, Money unitPrice) {
    final lines = [...state.lines];
    final idx = lines.indexWhere((l) => l.productId == productId);
    if (idx < 0) return;
    final line = lines[idx];
    // Preserva la cantidad en unidades base al cambiar de unidad.
    final baseQty = line.quantity * line.factor;
    var newQty = factor > 0 ? baseQty / factor : 1.0;
    if (newQty < 1 && factor > 1) newQty = 1;
    lines[idx] = line.copyWith(
      unitId: unitId,
      factor: factor,
      unitPrice: unitPrice,
      quantity: newQty,
    );
    state = state.copyWith(lines: lines);
  }

  void remove(int productId) {
    state = state.copyWith(
      lines: state.lines.where((l) => l.productId != productId).toList(),
    );
  }

  void clear() {
    state = const CartState(method: PaymentMethod.cash);
  }

  void setCustomer({int? id, String? dni, String? name}) {
    state = state.copyWith(
      customerId: () => id,
      customerDni: () => dni,
      customerName: () => name,
    );
  }

  void setMethod(PaymentMethod method) {
    state = state.copyWith(method: method);
  }

  void setReceived(Money received) {
    state = state.copyWith(received: received);
  }

  void setDiscount(Money discount) {
    state = state.copyWith(discount: discount);
  }
}
