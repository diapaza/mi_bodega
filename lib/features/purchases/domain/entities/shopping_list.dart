/// Lista de compras persistente.
library;

class ShoppingListItem {
  final int? id;
  final int storeId;
  final int productId;
  final double? quantity;
  final String? photoPath;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ShoppingListItem({
    this.id,
    required this.storeId,
    required this.productId,
    this.quantity,
    this.photoPath,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  ShoppingListItem copyWith({
    int? id,
    int? storeId,
    int? productId,
    double? quantity,
    String? photoPath,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ShoppingListItem(
      id: id ?? this.id,
      storeId: storeId ?? this.storeId,
      productId: productId ?? this.productId,
      quantity: quantity ?? this.quantity,
      photoPath: photoPath ?? this.photoPath,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
