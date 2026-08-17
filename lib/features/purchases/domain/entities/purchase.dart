/// Entidades de compras y proveedores.
library;

import 'package:mi_bodega/core/money/money.dart';

class Supplier {
  final int? id;
  final int storeId;
  final String name;
  final String? rucDni;
  final String? phone;
  final String? address;
  final bool active;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Supplier({
    this.id,
    required this.storeId,
    required this.name,
    this.rucDni,
    this.phone,
    this.address,
    this.active = true,
    required this.createdAt,
    required this.updatedAt,
  });

  Supplier copyWith({
    int? id,
    int? storeId,
    String? name,
    String? rucDni,
    String? phone,
    String? address,
    bool? active,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Supplier(
      id: id ?? this.id,
      storeId: storeId ?? this.storeId,
      name: name ?? this.name,
      rucDni: rucDni ?? this.rucDni,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      active: active ?? this.active,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

enum PurchaseStatus { pending, completed, cancelled }

class Purchase {
  final int? id;
  final int storeId;
  final int? supplierId;
  final int userId;
  final Money total;
  final Money discount;
  final DateTime purchaseDate;
  final PurchaseStatus status;
  final String? note;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Purchase({
    this.id,
    required this.storeId,
    this.supplierId,
    required this.userId,
    this.total = const Money.zero(),
    this.discount = const Money.zero(),
    required this.purchaseDate,
    this.status = PurchaseStatus.completed,
    this.note,
    required this.createdAt,
    required this.updatedAt,
  });
}

class PurchaseItem {
  final int? id;
  final int? purchaseId;
  final int productId;
  final double quantity;
  final int? unitId;
  final Money unitPrice;
  final double factor;
  final Money subtotal;

  const PurchaseItem({
    this.id,
    this.purchaseId,
    required this.productId,
    required this.quantity,
    this.unitId,
    this.unitPrice = const Money.zero(),
    this.factor = 1,
    this.subtotal = const Money.zero(),
  });
}

class PurchaseItemInput {
  final int productId;
  final double quantity;
  final int? unitId;
  final double factor;
  final Money unitPrice;

  const PurchaseItemInput({
    required this.productId,
    required this.quantity,
    this.unitId,
    this.factor = 1,
    this.unitPrice = const Money.zero(),
  });
}

class PurchaseRequest {
  final int storeId;
  final int userId;
  final int? supplierId;
  final List<PurchaseItemInput> items;
  final Money discount;
  final String? note;

  const PurchaseRequest({
    required this.storeId,
    required this.userId,
    this.supplierId,
    required this.items,
    this.discount = const Money.zero(),
    this.note,
  });
}
