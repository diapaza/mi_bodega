import 'package:drift/drift.dart';

import 'products.dart';
import 'system.dart';

/// Lista de compras persistente por tienda.
class ShoppingListItems extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get storeId => integer().references(Stores, #id)();

  IntColumn get productId => integer().references(Products, #id)();

  RealColumn get quantity => real().nullable()();

  TextColumn get photoPath => text().nullable()();

  TextColumn get notes => text().nullable()();

  DateTimeColumn get createdAt =>
      dateTime().clientDefault(() => DateTime.now())();

  DateTimeColumn get updatedAt =>
      dateTime().clientDefault(() => DateTime.now())();
}
