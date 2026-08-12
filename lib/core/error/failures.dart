import 'package:sqlite3/sqlite3.dart';

import 'result.dart';

/// Mapea excepciones de la base de datos a [Failure] de dominio.
Failure failureFrom(
  Object error, {
  String message = 'Operación no completada.',
}) {
  if (error is SqliteException) {
    // Códigos extendidos de SQLite.
    const uniqueConstraint = 2067; // SQLITE_CONSTRAINT_UNIQUE
    const foreignKeyConstraint = 787; // SQLITE_CONSTRAINT_FOREIGNKEY
    const checkConstraint = 275; // SQLITE_CONSTRAINT_CHECK
    const primaryKeyConstraint = 1555; // SQLITE_CONSTRAINT_PRIMARYKEY
    const readOnly = 8; // SQLITE_READONLY
    const cannotOpen = 14; // SQLITE_CANTOPEN

    switch (error.extendedResultCode) {
      case uniqueConstraint:
      case primaryKeyConstraint:
        return Failure(
          code: FailureCode.alreadyExists,
          message: 'Ya existe un registro con esos datos.',
          cause: error,
        );
      case foreignKeyConstraint:
        return Failure(
          code: FailureCode.constraintViolation,
          message: 'El registro está vinculado a otros datos.',
          cause: error,
        );
      case checkConstraint:
        return Failure(
          code: FailureCode.constraintViolation,
          message: 'Datos no válidos.',
          cause: error,
        );
      case readOnly:
      case cannotOpen:
        return Failure(
          code: FailureCode.deviceError,
          message: 'No se pudo acceder a la base de datos local.',
          cause: error,
        );
      default:
        return Failure(
          code: FailureCode.unexpected,
          message: message,
          cause: error,
        );
    }
  }
  if (error is FormatException || error is ArgumentError) {
    return Failure(
      code: FailureCode.validation,
      message: 'Datos ingresados no válidos.',
      cause: error,
    );
  }
  return Failure(
    code: FailureCode.unexpected,
    message: message,
    cause: error,
  );
}
