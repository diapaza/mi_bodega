/// Entidades del catálogo: categorías, marcas y unidades.
library;

class Category {
  final int? id;
  final String name;
  final bool active;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Category({
    this.id,
    required this.name,
    this.active = true,
    required this.createdAt,
    required this.updatedAt,
  });
}

class Brand {
  final int? id;
  final String name;
  final bool active;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Brand({
    this.id,
    required this.name,
    this.active = true,
    required this.createdAt,
    required this.updatedAt,
  });
}

enum UnitType { unit, weight, volume, package, other }

class Unit {
  final int? id;
  final String name;
  final String symbol;
  final UnitType unitType;
  final bool active;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Unit({
    this.id,
    required this.name,
    required this.symbol,
    this.unitType = UnitType.unit,
    this.active = true,
    required this.createdAt,
    required this.updatedAt,
  });
}

extension UnitTypeX on UnitType {
  String get name {
    return switch (this) {
      UnitType.unit => 'unit',
      UnitType.weight => 'weight',
      UnitType.volume => 'volume',
      UnitType.package => 'package',
      UnitType.other => 'other',
    };
  }

  static UnitType fromName(String? name) {
    return switch (name) {
      'weight' => UnitType.weight,
      'volume' => UnitType.volume,
      'package' => UnitType.package,
      'other' => UnitType.other,
      _ => UnitType.unit,
    };
  }
}
