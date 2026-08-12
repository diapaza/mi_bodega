/// Genera el número secuencial de venta visible (`V-000001`).
///
/// El número se calcula dentro de la transacción que registra la venta para
/// evitar colisiones de concurrencia (escritor único local).
library;

class SaleNumberGenerator {
  final String prefix;
  final int padding;

  const SaleNumberGenerator({this.prefix = 'V-', this.padding = 6});

  /// Calcula el siguiente número a partir del último número conocido.
  /// Devuelve `V-000001` si [lastNumber] es nulo o vacío.
  String next(String? lastNumber) {
    var lastValue = 0;
    if (lastNumber != null) {
      final parsed = int.tryParse(lastNumber.replaceFirst(prefix, ''));
      lastValue = parsed ?? 0;
    }
    final next = lastValue + 1;
    return '$prefix${next.toString().padLeft(padding, '0')}';
  }
}
