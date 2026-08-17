import 'package:intl/intl.dart';

/// Formatea una cantidad numérica para visualización.
/// Enteros se muestran sin decimales; decimales con 2 cifras.
String fmtQty(double v) {
  if (v == v.roundToDouble()) return '${v.toInt()}';
  return v.toStringAsFixed(2);
}

/// Formatea una fecha y hora en formato local legible.
/// Ejemplo: "15/06/2025 14:30"
String fmtDateTime(DateTime d) {
  return DateFormat('dd/MM/yyyy HH:mm', 'es').format(d);
}

/// Formatea solo una fecha (sin hora).
/// Ejemplo: "15/06/2025"
String fmtDate(DateTime d) {
  return DateFormat('dd/MM/yyyy', 'es').format(d);
}
