/// Guard de permisos de aplicación.
///
/// Los permisos no solo ocultan la UI: toda operación sensible pasa por
/// [ensureAllowed] en la lógica de la aplicación antes de ejecutarse.
library;

import 'package:mi_bodega/core/error/result.dart';

Result<void> ensureAllowed(Set<String> permissions, String required) {
  if (permissions.contains(required)) {
    return const Ok(null);
  }
  return const Err(Failure(
    code: FailureCode.forbidden,
    message: 'No tienes permiso para realizar esta acción.',
  ));
}
