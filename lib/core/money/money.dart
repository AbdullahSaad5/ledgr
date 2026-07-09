import 'package:decimal/decimal.dart';
import 'package:meta/meta.dart';

/// Thrown when an operation combines two [Money] values of different
/// currencies.
class CurrencyMismatchError extends Error {
  CurrencyMismatchError(this.a, this.b);

  final String a;
  final String b;

  @override
  String toString() => 'CurrencyMismatchError: $a vs $b';
}

/// An immutable amount of money in integer **minor units** (paisa, cents).
///
/// See ADR-0002. No floating point is ever used for money: all arithmetic is
/// on [minor]. Value equality by (minor, currency). Hand-written (not freezed)
/// so its test loop stays codegen-free.
@immutable
class Money implements Comparable<Money> {
  const Money({required this.minor, required this.currency});

  /// Zero in [currency].
  const Money.zero(this.currency) : minor = 0;

  /// Parse a [Decimal] major-unit amount into minor units for [currency],
  /// rounding half-to-even (banker's rounding) at the currency's scale.
  factory Money.fromDecimal(Decimal value, String currency) {
    final digits = decimalDigitsFor(currency);
    final factor = Decimal.fromBigInt(BigInt.from(10).pow(digits));
    final scaled = value * factor;
    return Money(minor: _roundHalfEven(scaled).toInt(), currency: currency);
  }

  /// Sum of [items], all of [currency]; empty sums to zero.
  factory Money.sum(Iterable<Money> items, String currency) {
    var total = 0;
    for (final m in items) {
      if (m.currency != currency) {
        throw CurrencyMismatchError(currency, m.currency);
      }
      total += m.minor;
    }
    return Money(minor: total, currency: currency);
  }

  /// Signed amount in the smallest currency unit.
  final int minor;

  /// ISO 4217 currency code.
  final String currency;

  int get decimalDigits => decimalDigitsFor(currency);

  bool get isZero => minor == 0;
  bool get isNegative => minor < 0;
  bool get isPositive => minor > 0;

  Money operator +(Money other) =>
      Money(minor: minor + _sameCurrency(other), currency: currency);

  Money operator -(Money other) =>
      Money(minor: minor - _sameCurrency(other), currency: currency);

  Money operator *(int quantity) =>
      Money(minor: minor * quantity, currency: currency);

  Money operator -() => Money(minor: -minor, currency: currency);

  bool operator <(Money other) => minor < _sameCurrency(other);
  bool operator <=(Money other) => minor <= _sameCurrency(other);
  bool operator >(Money other) => minor > _sameCurrency(other);
  bool operator >=(Money other) => minor >= _sameCurrency(other);

  /// Split into [parts] amounts that sum exactly to this value; any remainder
  /// (in minor units) is distributed one unit each to the leading parts.
  List<Money> split(int parts) {
    if (parts <= 0) {
      throw ArgumentError.value(parts, 'parts', 'must be positive');
    }
    final base = minor ~/ parts;
    final remainder = minor - base * parts;
    final step = remainder.isNegative ? -1 : 1;
    var left = remainder.abs();
    return List.generate(parts, (i) {
      final extra = left > 0 ? step : 0;
      if (left > 0) left--;
      return Money(minor: base + extra, currency: currency);
    });
  }

  /// The major-unit value as an exact [Decimal].
  Decimal toDecimal() {
    final factor = Decimal.fromBigInt(BigInt.from(10).pow(decimalDigits));
    return (Decimal.fromInt(minor) / factor).toDecimal();
  }

  int _sameCurrency(Money other) {
    if (other.currency != currency) {
      throw CurrencyMismatchError(currency, other.currency);
    }
    return other.minor;
  }

  @override
  int compareTo(Money other) => minor.compareTo(_sameCurrency(other));

  @override
  bool operator ==(Object other) =>
      other is Money && other.minor == minor && other.currency == currency;

  @override
  int get hashCode => Object.hash(minor, currency);

  @override
  String toString() => 'Money($minor $currency)';

  static BigInt _roundHalfEven(Decimal scaled) {
    final floor = scaled.floor().toBigInt();
    final frac = scaled - Decimal.fromBigInt(floor);
    final half = Decimal.parse('0.5');
    if (frac < half) return floor;
    if (frac > half) return floor + BigInt.one;
    // Exactly halfway: round toward the even neighbour.
    return floor.isEven ? floor : floor + BigInt.one;
  }
}

/// Minor-unit exponent per ISO 4217. Defaults to 2; only the exceptions the app
/// realistically encounters are listed. Extend as needed.
int decimalDigitsFor(String currency) {
  const zeroDigit = {'JPY', 'KRW', 'VND', 'CLP', 'ISK', 'UGX', 'PYG', 'RWF'};
  const threeDigit = {'KWD', 'BHD', 'OMR', 'TND', 'JOD', 'IQD', 'LYD'};
  if (zeroDigit.contains(currency)) return 0;
  if (threeDigit.contains(currency)) return 3;
  return 2;
}
