import 'package:mi_bodega/core/database/app_database.dart' as db;
import 'package:mi_bodega/core/database/daos.dart' as daos;
import 'package:drift/drift.dart';
import 'package:mi_bodega/core/error/failures.dart';
import 'package:mi_bodega/core/error/result.dart';
import 'package:mi_bodega/features/purchases/domain/entities/purchase.dart';
import 'package:mi_bodega/features/purchases/domain/repositories/purchase_repository.dart';

class DriftSupplierRepository implements SupplierRepository {
  final db.AppDatabase database;

  DriftSupplierRepository(this.database);

  daos.PurchaseDao get _purchaseDao => database.purchaseDao;

  @override
  Stream<List<Supplier>> watchSuppliers(int storeId, {bool onlyActive = true}) {
    return _purchaseDao.watchSuppliers(storeId, onlyActive: onlyActive).map((rows) {
      return rows.map(_map).toList();
    });
  }

  @override
  Future<Result<Supplier>> createSupplier(Supplier supplier) async {
    try {
      final id = await _purchaseDao.insertSupplier(db.SuppliersCompanion.insert(
        storeId: supplier.storeId,
        name: supplier.name,
        rucDni: _text(supplier.rucDni),
        phone: _text(supplier.phone),
        address: _text(supplier.address),
      ));
      final row = await _purchaseDao.supplierById(id);
      return Ok(_map(row!));
    } catch (e) {
      return Err(failureFrom(e));
    }
  }

  @override
  Future<Result<Supplier>> updateSupplier(Supplier supplier) async {
    try {
      final existing = await _purchaseDao.supplierById(supplier.id!);
      if (existing == null) {
        return const Err(Failure(
          code: FailureCode.notFound,
          message: 'Proveedor no encontrado.',
        ));
      }
      final updated = existing.toCompanion(true).copyWith(
            name: Value(supplier.name),
            rucDni: _text(supplier.rucDni),
            phone: _text(supplier.phone),
            address: _text(supplier.address),
            active: Value(supplier.active),
            updatedAt: Value(DateTime.now()),
          );
      await _purchaseDao.updateSupplier(updated);
      final row = await _purchaseDao.supplierById(supplier.id!);
      return Ok(_map(row!));
    } catch (e) {
      return Err(failureFrom(e));
    }
  }

  @override
  Future<Result<void>> setActive(int id, bool active) async {
    try {
      await (database.update(database.suppliers)..where((t) => t.id.equals(id)))
          .write(db.SuppliersCompanion(
        active: Value(active),
        updatedAt: Value(DateTime.now()),
      ));
      return const Ok(null);
    } catch (e) {
      return Err(failureFrom(e));
    }
  }

  Supplier _map(db.Supplier s) {
    return Supplier(
      id: s.id,
      storeId: s.storeId,
      name: s.name,
      rucDni: s.rucDni,
      phone: s.phone,
      address: s.address,
      active: s.active,
      createdAt: s.createdAt,
      updatedAt: s.updatedAt,
    );
  }

  static Value<String?> _text(String? v) =>
      v == null ? const Value.absent() : Value(v);
}
