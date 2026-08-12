import 'package:mi_bodega/core/database/app_database.dart' as db;
import 'package:mi_bodega/core/database/daos.dart' as daos;
import 'package:drift/drift.dart';
import 'package:mi_bodega/core/error/failures.dart';
import 'package:mi_bodega/core/error/result.dart';
import 'package:mi_bodega/features/store/domain/entities/store.dart';
import 'package:mi_bodega/features/store/domain/repositories/store_repository.dart';

class DriftStoreRepository implements StoreRepository {
  final db.AppDatabase database;

  DriftStoreRepository(this.database);

  daos.StoreDao get _dao => database.storeDao;

  @override
  Future<Result<Store?>> getStore() async {
    try {
      final row = await _dao.firstStore();
      return Ok(row == null ? null : _map(row));
    } catch (e) {
      return Err(failureFrom(e));
    }
  }

  @override
  Stream<Store?> watchStore() {
    return _dao.watchFirstStore().map((s) => s == null ? null : _map(s));
  }

  @override
  Future<Result<Store>> createStore(Store store) async {
    try {
      final id = await _dao.insertStore(db.StoresCompanion.insert(
        name: store.name,
        rucDni: _text(store.rucDni),
        address: _text(store.address),
        phone: _text(store.phone),
        currency: Value(store.currency),
      ));
      final row = await (database.select(database.stores)
            ..where((t) => t.id.equals(id)))
          .getSingleOrNull();
      return Ok(_map(row!));
    } catch (e) {
      return Err(failureFrom(e));
    }
  }

  @override
  Future<Result<Store>> updateStore(Store store) async {
    try {
      final existing = await _dao.firstStore();
      if (existing == null) {
        return const Err(Failure(
          code: FailureCode.notFound,
          message: 'Tienda no encontrada.',
        ));
      }
      final updated = existing.toCompanion(true).copyWith(
            name: Value(store.name),
            rucDni: _text(store.rucDni),
            address: _text(store.address),
            phone: _text(store.phone),
            currency: Value(store.currency),
            updatedAt: Value(DateTime.now()),
          );
      await _dao.updateStore(updated);
      final row = await _dao.firstStore();
      return Ok(_map(row!));
    } catch (e) {
      return Err(failureFrom(e));
    }
  }

  @override
  Future<Result<String?>> getSetting(String key) async {
    try {
      return Ok(await _dao.getSetting(key));
    } catch (e) {
      return Err(failureFrom(e));
    }
  }

  @override
  Stream<String?> watchSetting(String key) => _dao.watchSetting(key);

  @override
  Future<Result<void>> putSetting(String key, String value) async {
    try {
      await _dao.putSetting(key, value);
      return const Ok(null);
    } catch (e) {
      return Err(failureFrom(e));
    }
  }

  Store _map(db.Store s) => Store(
        id: s.id,
        name: s.name,
        rucDni: s.rucDni,
        address: s.address,
        phone: s.phone,
        currency: s.currency,
        active: s.active,
        createdAt: s.createdAt,
        updatedAt: s.updatedAt,
      );

  static Value<String?> _text(String? v) =>
      v == null ? const Value.absent() : Value(v);
}
