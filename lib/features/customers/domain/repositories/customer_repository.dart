import 'package:mi_bodega/core/error/result.dart';
import 'package:mi_bodega/features/customers/domain/entities/customer.dart';
import 'package:mi_bodega/features/sales/domain/entities/sale.dart';

/// Contrato de clientes.
abstract interface class CustomerRepository {
  Future<Result<List<Customer>>> search(String query, int storeId);

  Future<Result<Customer>> create(Customer customer);

  Future<Result<int?>> findOrCreate({
    required int storeId,
    required String name,
    String? dni,
  });

  Future<Result<Customer?>> customerById(int id);

  /// Total comprado, última compra y nº de compras (ventas completadas).
  Future<Result<CustomerStats>> customerStats(int customerId);

  /// Historial de ventas del cliente.
  Stream<List<Sale>> watchCustomerSales(int customerId);
}
