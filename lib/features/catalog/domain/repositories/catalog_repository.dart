import 'package:mi_bodega/core/error/result.dart';
import 'package:mi_bodega/features/catalog/domain/entities/catalog.dart';

/// Contrato de catálogo (categorías, marcas, unidades).
abstract interface class CatalogRepository {
  Stream<List<Category>> watchCategories();

  Future<Result<List<Category>>> listCategories();

  Future<Result<Category>> createCategory(String name);

  Future<Result<void>> updateCategory(Category category);

  Future<Result<void>> setCategoryActive(int id, bool active);

  Stream<List<Brand>> watchBrands();

  Future<Result<Brand>> createBrand(String name);

  Future<Result<void>> updateBrand(Brand brand);

  Future<Result<void>> setBrandActive(int id, bool active);

  Stream<List<Unit>> watchUnits();

  Future<Result<List<Unit>>> listUnits();

  Future<Result<Unit>> createUnit(String name, String symbol, UnitType type);

  Future<Result<void>> updateUnit(Unit unit);

  Future<Result<void>> setUnitActive(int id, bool active);
}
