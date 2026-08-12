/// Resultado sellado para operaciones de dominio.
///
/// Evita el manejo informal de errores con excepciones en las capas
/// superiores: el dominio retorna `Ok(value)` o `Err(failure)`.
library;

sealed class Result<T> {
  const Result();

  bool get isOk => this is Ok<T>;

  bool get isErr => this is Err<T>;

  R fold<R>(R Function(T value) onOk, R Function(Failure failure) onErr) {
    return switch (this) {
      Ok<T>(:final value) => onOk(value),
      Err<T>(:final failure) => onErr(failure),
    };
  }

  T? get orNull => switch (this) {
        Ok<T>(:final value) => value,
        Err<T>() => null,
      };

  Failure? get failure => switch (this) {
        Err<T>(:final failure) => failure,
        Ok<T>() => null,
      };
}

class Ok<T> extends Result<T> {
  final T value;

  const Ok(this.value);
}

class Err<T> extends Result<T> {
  @override
  final Failure failure;

  const Err(this.failure);
}

enum FailureCode {
  validation,
  notFound,
  alreadyExists,
  insufficientStock,
  negativeStock,
  noOpenCashSession,
  cashSessionAlreadyOpen,
  cashSessionClosed,
  constraintViolation,
  incompatibleBackup,
  backupCorrupted,
  locked,
  needsAuthorization,
  forbidden,
  deviceError,
  unexpected,
}

/// Fallo tipado de dominio.
class Failure {
  final FailureCode code;
  final String message;
  final Object? cause;

  const Failure({
    required this.code,
    required this.message,
    this.cause,
  });

  @override
  String toString() => 'Failure($code): $message';
}
