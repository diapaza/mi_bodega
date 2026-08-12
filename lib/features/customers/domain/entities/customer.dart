/// Entidad Cliente.
library;

import 'package:mi_bodega/core/money/money.dart';

class Customer {
  final int? id;
  final int storeId;
  final String name;
  final String? dni;
  final String? phone;
  final String? email;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Customer({
    this.id,
    required this.storeId,
    required this.name,
    this.dni,
    this.phone,
    this.email,
    required this.createdAt,
    required this.updatedAt,
  });
}

/// Estadísticas de compras de un cliente (solo ventas completadas).
class CustomerStats {
  final Money totalSpent;
  final DateTime? lastPurchaseAt;
  final int purchaseCount;

  const CustomerStats({
    required this.totalSpent,
    required this.lastPurchaseAt,
    required this.purchaseCount,
  });
}
