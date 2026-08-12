/// Value object inmutable para representar dinero.
///
/// Todo monto se almacena como [cents] (entero), evitando el uso de
/// `double`/`float` para aritmética monetaria.
library;

class Money implements Comparable<Money> {
  final int cents;

  const Money(this.cents);

  const Money.zero() : cents = 0;

  factory Money.fromSoles(double soles) => Money((soles * 100).round());

  factory Money.fromCents(int cents) => Money(cents);

  Money operator +(Money other) => Money(cents + other.cents);

  Money operator -(Money other) => Money(cents - other.cents);

  Money operator *(num factor) => Money((cents * factor).round());

  Money operator /(num divisor) => Money((cents / divisor).round());

  bool operator <(Money other) => cents < other.cents;

  bool operator <=(Money other) => cents <= other.cents;

  bool operator >(Money other) => cents > other.cents;

  bool operator >=(Money other) => cents >= other.cents;

  Money get abs => Money(cents.abs());

  Money get negated => Money(-cents);

  bool get isNegative => cents < 0;

  bool get isZero => cents == 0;

  double toSoles() => cents / 100;

  /// Redondeo half-up: útil al prorratear descuentos entre líneas.
  Money share(double fraction) => Money((cents * fraction).round());

  @override
  int compareTo(Money other) => cents.compareTo(other.cents);

  @override
  bool operator ==(Object other) => other is Money && other.cents == cents;

  @override
  int get hashCode => cents.hashCode;

  /// Formatea como moneda peruana: `S/ 1,234.56`.
  String format() {
    final sign = isNegative ? '-' : '';
    final absCents = cents.abs();
    final intPart = absCents ~/ 100;
    final decPart = (absCents % 100).toString().padLeft(2, '0');
    return '${sign}S/ ${_groupThousands(intPart)}.$decPart';
  }

  static String _groupThousands(int value) {
    final digits = value.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }

  @override
  String toString() => format();
}
