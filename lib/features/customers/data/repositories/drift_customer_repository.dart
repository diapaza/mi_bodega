import 'package:drift/drift.dart';

import 'package:mi_bodega/core/database/app_database.dart' as db;
import 'package:mi_bodega/core/error/failures.dart';
import 'package:mi_bodega/core/error/result.dart';
import 'package:mi_bodega/core/money/money.dart';
import 'package:mi_bodega/features/customers/domain/entities/customer.dart';
import 'package:mi_bodega/features/customers/domain/repositories/customer_repository.dart';
import 'package:mi_bodega/features/sales/domain/entities/sale.dart';

class DriftCustomerRepository implements CustomerRepository {
  final db.AppDatabase database;

  DriftCustomerRepository(this.database);

  @override
  Future<Result<List<Customer>>> search(String query, int storeId) async {
    try {
      final q = query.trim();
      final rows = await (database.select(database.customers)
            ..where((t) => t.storeId.equals(storeId) & (t.name.like('%$q%') | t.dni.like('%$q%')))
            ..orderBy([(t) => OrderingTerm.asc(t.name)])
            ..limit(20))
          .get();
      return Ok(rows.map(_map).toList());
    } catch (e) {
      return Err(failureFrom(e));
    }
  }

  @override
  Future<Result<Customer>> create(Customer customer) async {
    try {
      final id = await (database.into(database.customers)).insert(db.CustomersCompanion.insert(
        storeId: customer.storeId,
        name: customer.name,
        dni: customer.dni == null ? const Value.absent() : Value(customer.dni),
        phone: customer.phone == null ? const Value.absent() : Value(customer.phone),
        email: customer.email == null ? const Value.absent() : Value(customer.email),
      ));
      final row = await (database.select(database.customers)
            ..where((t) => t.id.equals(id)))
          .getSingleOrNull();
      return Ok(_map(row!));
    } catch (e) {
      return Err(failureFrom(e));
    }
  }

  @override
  Future<Result<int?>> findOrCreate({
    required int storeId,
    required String name,
    String? dni,
  }) async {
    try {
      final trimmed = name.trim();
      if (trimmed.isEmpty) return const Ok(null);
      final existing = await (database.select(database.customers)
            ..where((t) => t.storeId.equals(storeId) & t.name.equals(trimmed))
            ..limit(1))
          .getSingleOrNull();
      if (existing != null) return Ok(existing.id);
      final id = await (database.into(database.customers)).insert(db.CustomersCompanion.insert(
        storeId: storeId,
        name: trimmed,
        dni: dni == null ? const Value.absent() : Value(dni),
      ));
      return Ok(id);
    } catch (e) {
      return Err(failureFrom(e));
    }
  }

  @override
  Future<Result<Customer?>> customerById(int id) async {
    try {
      final row = await (database.select(database.customers)
            ..where((t) => t.id.equals(id)))
          .getSingleOrNull();
      return Ok(row == null ? null : _map(row));
    } catch (e) {
      return Err(failureFrom(e));
    }
  }

  @override
  Future<Result<CustomerStats>> customerStats(int customerId) async {
    try {
      final row = await (database.selectOnly(database.sales)
            ..addColumns([
              database.sales.total.sum(),
              database.sales.id.count(),
              database.sales.saleDate.max(),
            ])
            ..where(database.sales.customerId.equals(customerId) &
                database.sales.status.equals('completed')))
          .getSingle();
      return Ok(CustomerStats(
        totalSpent: Money(row.read(database.sales.total.sum()) ?? 0),
        lastPurchaseAt: row.read(database.sales.saleDate.max()),
        purchaseCount: row.read(database.sales.id.count()) ?? 0,
      ));
    } catch (e) {
      return Err(failureFrom(e));
    }
  }

  @override
  Stream<List<Sale>> watchCustomerSales(int customerId) {
    return (database.select(database.sales)
          ..where((t) => t.customerId.equals(customerId))
          ..orderBy([(t) => OrderingTerm.desc(t.id)]))
        .watch()
        .map((rows) => rows.map(_mapSale).toList());
  }

  Sale _mapSale(db.Sale s) {
    return Sale(
      id: s.id,
      storeId: s.storeId,
      saleNumber: s.saleNumber,
      cashSessionId: s.cashSessionId,
      customerId: s.customerId,
      userId: s.userId,
      subtotal: Money(s.subtotal),
      discount: Money(s.discount),
      total: Money(s.total),
      paymentMethod: PaymentMethodX.fromName(s.paymentMethod),
      amountReceived: s.amountReceived == null ? null : Money(s.amountReceived!),
      changeDue: s.changeDue == null ? null : Money(s.changeDue!),
      status: s.status == 'cancelled' ? SaleStatus.cancelled : SaleStatus.completed,
      cancelReason: s.cancelReason,
      saleDate: s.saleDate,
      note: s.note,
      createdAt: s.createdAt,
      updatedAt: s.updatedAt,
    );
  }

  Customer _map(db.Customer c) => Customer(
        id: c.id,
        storeId: c.storeId,
        name: c.name,
        dni: c.dni,
        phone: c.phone,
        email: c.email,
        createdAt: c.createdAt,
        updatedAt: c.updatedAt,
      );
}
