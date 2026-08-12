import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mi_bodega/core/money/money.dart';
import 'package:mi_bodega/features/pos/presentation/cart_controller.dart';
import 'package:mi_bodega/features/products/domain/entities/product.dart';
import 'package:mi_bodega/features/sales/domain/entities/sale.dart';

ProductStock _stock(double stock, {Money price = const Money(350), int baseUnitId = 1}) {
  return ProductStock(
    Product(
      id: 1,
      storeId: 1,
      baseUnitId: baseUnitId,
      name: 'Leche',
      salePrice: price,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    ),
    stock,
  );
}

void main() {
  late ProviderContainer container;
  late CartController cart;

  setUp(() {
    container = ProviderContainer();
    cart = container.read(cartProvider.notifier);
  });

  tearDown(() => container.dispose());

  group('CartController', () {
    test('agregar e incrementar con límite de stock', () {
      final item = _stock(3);
      expect(cart.add(item), isTrue); // qty 1
      expect(cart.add(item), isTrue); // qty 2
      expect(cart.add(item), isTrue); // qty 3
      expect(cart.add(item), isFalse); // stock agotado
      expect(container.read(cartProvider).lines.single.quantity, 3);
    });

    test('decrementar a cero elimina la línea', () {
      cart.add(_stock(5));
      cart.increment(1);
      expect(container.read(cartProvider).lines.single.quantity, 2);
      cart.decrement(1);
      cart.decrement(1);
      expect(container.read(cartProvider).isEmpty, isTrue);
    });

    test('subtotal y total con descuento', () {
      cart.add(_stock(10, price: const Money(350)));
      cart.add(_stock(10, price: const Money(350))); // mismo producto → qty 2
      cart.setQuantity(1, 3);
      expect(container.read(cartProvider).subtotal.cents, 1050); // 3 × 350
      cart.setDiscount(const Money(100));
      expect(container.read(cartProvider).total.cents, 950);
      cart.setDiscount(const Money(99999));
      expect(container.read(cartProvider).total.cents, 0); // nunca negativo
    });

    test('setQuantity respeta stock y 0 elimina', () {
      cart.add(_stock(10));
      cart.setQuantity(1, 99);
      expect(container.read(cartProvider).lines.single.quantity, 10);
      cart.setQuantity(1, 0);
      expect(container.read(cartProvider).isEmpty, isTrue);
    });

    test('cambio y faltante en efectivo', () {
      cart.add(_stock(10, price: const Money(1750))); // total 17.50
      cart.setMethod(PaymentMethod.cash);
      cart.setReceived(const Money(2000)); // 20.00
      final state = container.read(cartProvider);
      expect(state.change.cents, 250); // vuelto 2.50
      expect(state.missing.isZero, isTrue);

      cart.setReceived(const Money(1000));
      expect(container.read(cartProvider).missing.cents, 750);
    });

    test('cambio con método no efectivo es cero', () {
      cart.add(_stock(10, price: const Money(1750)));
      cart.setMethod(PaymentMethod.yape);
      cart.setReceived(const Money(2000));
      expect(container.read(cartProvider).change.isZero, isTrue);
    });

    test('cambiar unidad conserva la cantidad en unidades base', () {
      cart.add(_stock(48)); // 1 ud = 350, stock 48
      cart.setUnit(1, 2, 24, const Money(6000)); // caja ×24
      final state = container.read(cartProvider);
      // 1 unidad base → 1/24 caja, redondeado a 1 por convención.
      expect(state.lines.single.factor, 24);
      expect(state.lines.single.unitPrice.cents, 6000);

      // Volver a base: cantidad conservada (≈1).
      cart.setUnit(1, 1, 1, const Money(350));
      expect(container.read(cartProvider).lines.single.factor, 1);
    });

    test('cliente opcional y vaciado', () {
      cart.add(_stock(5));
      cart.setCustomer(id: 7, name: 'Cliente');
      expect(container.read(cartProvider).customerId, 7);
      cart.clear();
      expect(container.read(cartProvider).isEmpty, isTrue);
      expect(container.read(cartProvider).customerId, isNull);
    });
  });
}
