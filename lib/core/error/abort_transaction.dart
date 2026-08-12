import 'result.dart';

/// Excepción lanzada dentro de una transacción para abortarla con un
/// [Failure] de dominio (sin exponer detalles internos de la base de datos).
class AbortTransaction implements Exception {
  final Failure failure;

  const AbortTransaction(this.failure);
}
