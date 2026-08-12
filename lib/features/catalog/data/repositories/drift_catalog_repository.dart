import 'package:mi_bodega/core/database/app_database.dart' as db;
import 'package:mi_bodega/core/database/daos.dart' as daos;
import 'package:drift/drift.dart';
import 'package:mi_bodega/core/error/failures.dart';
import 'package:mi_bodega/core/error/result.dart';
import 'package:mi_bodega/features/catalog/domain/entities/catalog.dart';
import 'package:mi_bodega/features/catalog/domain/repositories/catalog_repository.dart';

class DriftCatalogRepository implements CatalogRepository {
  final db.AppDatabase database;

  DriftCatalogRepository(this.database);

  daos.CatalogDao get _dao => database.catalogDao;

  @override
  Stream<List<Category>> watchCategories() {
    return _dao.watchActiveCategories().map((rows) => rows.map(_category).toList());
  }

  @override
  Future<Result<List<Category>>> listCategories() async {
    try {
      final rows = await _dao.watchActiveCategories().first;
      return Ok(rows.map(_category).toList());
    } catch (e) {
      return Err(failureFrom(e));
    }
  }

  @override
  Future<Result<Category>> createCategory(String name) async {
    try {
      final id = await _dao.insertCategory(db.CategoriesCompanion.insert(name: name));
      final row = await _dao.categoryById(id);
      return Ok(_category(row!));
    } catch (e) {
      return Err(failureFrom(e));
    }
  }

  @override
  Future<Result<void>> updateCategory(Category category) async {
    try {
      final existing = await _dao.categoryById(category.id!);
      if (existing == null) {
        return const Err(Failure(
          code: FailureCode.notFound,
          message: 'Categoría no encontrada.',
        ));
      }
      final updated = existing.toCompanion(true).copyWith(
            name: Value(category.name),
            active: Value(category.active),
            updatedAt: Value(DateTime.now()),
          );
      await _dao.updateCategory(updated);
      return const Ok(null);
    } catch (e) {
      return Err(failureFrom(e));
    }
  }

  @override
  Future<Result<void>> setCategoryActive(int id, bool active) async {
    try {
      final existing = await _dao.categoryById(id);
      if (existing == null) {
        return const Err(Failure(
          code: FailureCode.notFound,
          message: 'Categoría no encontrada.',
        ));
      }
      await _dao.updateCategory(
        existing.toCompanion(true).copyWith(
              active: Value(active),
              updatedAt: Value(DateTime.now()),
            ),
      );
      return const Ok(null);
    } catch (e) {
      return Err(failureFrom(e));
    }
  }

  @override
  Stream<List<Brand>> watchBrands() {
    return _dao.watchActiveBrands().map((rows) => rows.map(_brand).toList());
  }

  @override
  Future<Result<Brand>> createBrand(String name) async {
    try {
      final id = await _dao.insertBrand(db.BrandsCompanion.insert(name: name));
      final row = await (database.select(database.brands)
            ..where((t) => t.id.equals(id)))
          .getSingleOrNull();
      return Ok(_brand(row!));
    } catch (e) {
      return Err(failureFrom(e));
    }
  }

  @override
  Future<Result<void>> updateBrand(Brand brand) async {
    try {
      final existing = await (database.select(database.brands)
            ..where((t) => t.id.equals(brand.id!)))
          .getSingleOrNull();
      if (existing == null) {
        return const Err(Failure(
          code: FailureCode.notFound,
          message: 'Marca no encontrada.',
        ));
      }
      await (database.update(database.brands)..where((t) => t.id.equals(brand.id!)))
          .write(db.BrandsCompanion(
        name: Value(brand.name),
        active: Value(brand.active),
        updatedAt: Value(DateTime.now()),
      ));
      return const Ok(null);
    } catch (e) {
      return Err(failureFrom(e));
    }
  }

  @override
  Future<Result<void>> setBrandActive(int id, bool active) async {
    try {
      await (database.update(database.brands)..where((t) => t.id.equals(id)))
          .write(db.BrandsCompanion(
        active: Value(active),
        updatedAt: Value(DateTime.now()),
      ));
      return const Ok(null);
    } catch (e) {
      return Err(failureFrom(e));
    }
  }

  @override
  Stream<List<Unit>> watchUnits() {
    return _dao.watchActiveUnits().map((rows) => rows.map(_unit).toList());
  }

  @override
  Future<Result<List<Unit>>> listUnits() async {
    try {
      final rows = await _dao.watchActiveUnits().first;
      return Ok(rows.map(_unit).toList());
    } catch (e) {
      return Err(failureFrom(e));
    }
  }

  @override
  Future<Result<Unit>> createUnit(String name, String symbol, UnitType type) async {
    try {
      final id = await _dao.insertUnit(db.UnitsCompanion.insert(
        name: name,
        symbol: symbol,
        unitType: Value(type.name),
      ));
      final row = await _dao.unitById(id);
      return Ok(_unit(row!));
    } catch (e) {
      return Err(failureFrom(e));
    }
  }

  @override
  Future<Result<void>> updateUnit(Unit unit) async {
    try {
      final existing = await _dao.unitById(unit.id!);
      if (existing == null) {
        return const Err(Failure(
          code: FailureCode.notFound,
          message: 'Unidad no encontrada.',
        ));
      }
      final updated = existing.toCompanion(true).copyWith(
            name: Value(unit.name),
            symbol: Value(unit.symbol),
            unitType: Value(unit.unitType.name),
            active: Value(unit.active),
            updatedAt: Value(DateTime.now()),
          );
      await _dao.updateUnit(updated);
      return const Ok(null);
    } catch (e) {
      return Err(failureFrom(e));
    }
  }

  @override
  Future<Result<void>> setUnitActive(int id, bool active) async {
    try {
      final existing = await _dao.unitById(id);
      if (existing == null) {
        return const Err(Failure(
          code: FailureCode.notFound,
          message: 'Unidad no encontrada.',
        ));
      }
      await _dao.updateUnit(existing.toCompanion(true).copyWith(
            active: Value(active),
            updatedAt: Value(DateTime.now()),
          ));
      return const Ok(null);
    } catch (e) {
      return Err(failureFrom(e));
    }
  }

  Category _category(db.Category c) => Category(
        id: c.id,
        name: c.name,
        active: c.active,
        createdAt: c.createdAt,
        updatedAt: c.updatedAt,
      );

  Brand _brand(db.Brand b) => Brand(
        id: b.id,
        name: b.name,
        active: b.active,
        createdAt: b.createdAt,
        updatedAt: b.updatedAt,
      );

  Unit _unit(db.Unit u) => Unit(
        id: u.id,
        name: u.name,
        symbol: u.symbol,
        unitType: UnitTypeX.fromName(u.unitType),
        active: u.active,
        createdAt: u.createdAt,
        updatedAt: u.updatedAt,
      );
}
