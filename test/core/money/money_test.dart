import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledgr/core/money/money.dart';

void main() {
  group('Money construction', () {
    test('holds minor units and currency', () {
      const m = Money(minor: 12345, currency: 'PKR');
      expect(m.minor, 12345);
      expect(m.currency, 'PKR');
    });

    test('zero helper', () {
      expect(const Money.zero('PKR'), const Money(minor: 0, currency: 'PKR'));
      expect(const Money.zero('PKR').isZero, isTrue);
    });

    test('value equality and hashCode', () {
      const a = Money(minor: 100, currency: 'PKR');
      const b = Money(minor: 100, currency: 'PKR');
      const c = Money(minor: 100, currency: 'USD');
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a == c, isFalse);
    });
  });

  group('Money arithmetic (integer, exact)', () {
    test('addition of same currency', () {
      const a = Money(minor: 120000, currency: 'PKR'); // 1200.00
      const b = Money(minor: 35000, currency: 'PKR'); //   350.00
      expect(a + b, const Money(minor: 155000, currency: 'PKR'));
    });

    test('subtraction can go negative', () {
      const a = Money(minor: 500, currency: 'PKR');
      const b = Money(minor: 800, currency: 'PKR');
      expect(a - b, const Money(minor: -300, currency: 'PKR'));
      expect((a - b).isNegative, isTrue);
    });

    test('multiplication by integer quantity', () {
      const price = Money(minor: 4500, currency: 'PKR');
      expect(price * 3, const Money(minor: 13500, currency: 'PKR'));
    });

    test('negate', () {
      expect(
        -const Money(minor: 250, currency: 'PKR'),
        const Money(minor: -250, currency: 'PKR'),
      );
    });

    test('mixing currencies throws', () {
      const a = Money(minor: 100, currency: 'PKR');
      const b = Money(minor: 100, currency: 'USD');
      expect(() => a + b, throwsA(isA<CurrencyMismatchError>()));
      expect(() => a - b, throwsA(isA<CurrencyMismatchError>()));
    });

    test('sum over a list', () {
      final items = [
        const Money(minor: 100, currency: 'PKR'),
        const Money(minor: 250, currency: 'PKR'),
        const Money(minor: 50, currency: 'PKR'),
      ];
      expect(Money.sum(items, 'PKR'), const Money(minor: 400, currency: 'PKR'));
      expect(Money.sum(const [], 'PKR'), const Money.zero('PKR'));
    });
  });

  group('Money.fromDecimal (parsing) — 2-digit currency', () {
    test('whole and fractional', () {
      expect(
        Money.fromDecimal(Decimal.parse('1200'), 'PKR'),
        const Money(minor: 120000, currency: 'PKR'),
      );
      expect(
        Money.fromDecimal(Decimal.parse('1200.50'), 'PKR'),
        const Money(minor: 120050, currency: 'PKR'),
      );
      expect(
        Money.fromDecimal(Decimal.parse('0.09'), 'PKR'),
        const Money(minor: 9, currency: 'PKR'),
      );
    });

    test('rounds half-even to the currency scale', () {
      // 1.005 -> banker's rounding at 2dp -> 1.00 (round to even)
      expect(Money.fromDecimal(Decimal.parse('1.005'), 'PKR').minor, 100);
      // 1.015 -> 1.02 (round to even)
      expect(Money.fromDecimal(Decimal.parse('1.015'), 'PKR').minor, 102);
      // 1.025 -> 1.02 (round to even)
      expect(Money.fromDecimal(Decimal.parse('1.025'), 'PKR').minor, 102);
    });

    test('negative parses', () {
      expect(
        Money.fromDecimal(Decimal.parse('-3.20'), 'PKR'),
        const Money(minor: -320, currency: 'PKR'),
      );
    });
  });

  group('Money currency scale', () {
    test('JPY has 0 decimal digits', () {
      expect(
        Money.fromDecimal(Decimal.parse('1200'), 'JPY'),
        const Money(minor: 1200, currency: 'JPY'),
      );
      expect(const Money(minor: 1200, currency: 'JPY').decimalDigits, 0);
    });

    test('PKR/USD have 2', () {
      expect(const Money(minor: 0, currency: 'PKR').decimalDigits, 2);
      expect(const Money(minor: 0, currency: 'USD').decimalDigits, 2);
    });
  });

  group('Money split (half-even remainder distribution)', () {
    test('splits evenly when divisible', () {
      final parts = const Money(minor: 900, currency: 'PKR').split(3);
      expect(parts, [
        const Money(minor: 300, currency: 'PKR'),
        const Money(minor: 300, currency: 'PKR'),
        const Money(minor: 300, currency: 'PKR'),
      ]);
    });

    test('distributes remainder to the first parts, conserving total', () {
      final parts = const Money(minor: 1000, currency: 'PKR').split(3);
      expect(parts.map((p) => p.minor).toList(), [334, 333, 333]);
      expect(Money.sum(parts, 'PKR').minor, 1000);
    });

    test('rejects non-positive part counts', () {
      expect(
        () => const Money(minor: 100, currency: 'PKR').split(0),
        throwsArgumentError,
      );
    });
  });

  group('Money.toDecimal', () {
    test('round-trips through minor units', () {
      expect(
        const Money(minor: 120050, currency: 'PKR').toDecimal(),
        Decimal.parse('1200.50'),
      );
      expect(
        const Money(minor: 1200, currency: 'JPY').toDecimal(),
        Decimal.parse('1200'),
      );
    });
  });
}
