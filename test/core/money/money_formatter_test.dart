import 'package:flutter_test/flutter_test.dart';
import 'package:ledgr/core/money/money.dart';
import 'package:ledgr/core/money/money_formatter.dart';

void main() {
  group('MoneyFormatter', () {
    test('formats with grouping and currency symbol', () {
      const f = MoneyFormatter(symbol: r'$', locale: 'en');
      expect(
        f.format(const Money(minor: 324000, currency: 'USD')),
        r'$3,240.00',
      );
      expect(f.format(const Money(minor: 9, currency: 'USD')), r'$0.09');
    });

    test('PKR renders whole rupees (0 decimals, locked in #3)', () {
      const f = MoneyFormatter(symbol: 'Rs ', locale: 'en');
      expect(
        f.format(const Money(minor: 3240, currency: 'PKR')),
        'Rs 3,240',
      );
    });

    test('negative amounts show a leading minus before the symbol', () {
      const f = MoneyFormatter(symbol: 'Rs ', locale: 'en');
      expect(
        f.format(const Money(minor: -500, currency: 'PKR')),
        '-Rs 500',
      );
    });

    test('respects zero-decimal currencies', () {
      const f = MoneyFormatter(symbol: '¥', locale: 'en');
      expect(f.format(const Money(minor: 1200, currency: 'JPY')), '¥1,200');
    });

    test('can omit the symbol', () {
      const f = MoneyFormatter(symbol: '', locale: 'en');
      expect(f.format(const Money(minor: 150050, currency: 'USD')), '1,500.50');
    });
  });
}
