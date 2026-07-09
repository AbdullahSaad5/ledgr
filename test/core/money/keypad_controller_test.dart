import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledgr/core/money/keypad_controller.dart';
import 'package:ledgr/core/money/money.dart';

void main() {
  late KeypadController c;
  setUp(() => c = KeypadController());

  group('digit entry', () {
    test('builds a number', () {
      c
        ..pressDigit('1')
        ..pressDigit('2')
        ..pressDigit('0')
        ..pressDigit('0');
      expect(c.expression, '1200');
      expect(c.isEmpty, isFalse);
    });

    test('starts empty', () {
      expect(c.expression, '');
      expect(c.isEmpty, isTrue);
      expect(c.evaluate(), Decimal.zero);
    });
  });

  group('decimal point', () {
    test('single decimal in a segment', () {
      c
        ..pressDigit('1')
        ..pressDecimal()
        ..pressDigit('5');
      expect(c.expression, '1.5');
    });

    test('second decimal in the same segment is ignored', () {
      c
        ..pressDigit('1')
        ..pressDecimal()
        ..pressDigit('5')
        ..pressDecimal()
        ..pressDigit('0');
      expect(c.expression, '1.50');
    });

    test('leading decimal becomes 0.', () {
      c.pressDecimal();
      expect(c.expression, '0.');
    });

    test('decimal after an operator becomes 0.', () {
      c
        ..pressDigit('5')
        ..pressOperator('+')
        ..pressDecimal();
      expect(c.expression, '5+0.');
    });
  });

  group('operators', () {
    test('chained operators build an expression', () {
      c
        ..pressDigit('1')
        ..pressDigit('2')
        ..pressOperator('+')
        ..pressDigit('3');
      expect(c.expression, '12+3');
      expect(c.evaluate(), Decimal.parse('15'));
    });

    test('operator with empty expression is ignored (except minus)', () {
      c.pressOperator('+');
      expect(c.expression, '');
      c.pressOperator('-');
      expect(c.expression, '-');
    });

    test('operator replaces a trailing operator', () {
      c
        ..pressDigit('9')
        ..pressOperator('+')
        ..pressOperator('*');
      expect(c.expression, '9*');
    });

    test('operator after a trailing decimal point strips the point', () {
      c
        ..pressDigit('5')
        ..pressDecimal()
        ..pressOperator('+');
      expect(c.expression, '5+');
    });
  });

  group('backspace and clear', () {
    test('backspace removes the last character', () {
      c
        ..pressDigit('1')
        ..pressDigit('2')
        ..backspace();
      expect(c.expression, '1');
    });

    test('backspace on empty is a no-op', () {
      c.backspace();
      expect(c.expression, '');
    });

    test('clear empties everything', () {
      c
        ..pressDigit('1')
        ..pressOperator('+')
        ..pressDigit('2')
        ..clear();
      expect(c.expression, '');
      expect(c.isEmpty, isTrue);
    });
  });

  group('evaluation to Money', () {
    test('converts an expression result to minor units', () {
      c
        ..pressDigit('1')
        ..pressDigit('2')
        ..pressDigit('0')
        ..pressDigit('0')
        ..pressOperator('+')
        ..pressDigit('3')
        ..pressDigit('5')
        ..pressDigit('0');
      expect(c.toMoney('PKR'), const Money(minor: 155000, currency: 'PKR'));
    });

    test('rounds a repeating result at the currency scale', () {
      c
        ..pressDigit('1')
        ..pressDigit('0')
        ..pressOperator('/')
        ..pressDigit('3');
      // 10/3 = 3.333... -> 333 minor (2dp)
      expect(c.toMoney('PKR'), const Money(minor: 333, currency: 'PKR'));
    });

    test('seeding from an existing amount (edit flow)', () {
      final seeded = KeypadController.fromMoney(
        const Money(minor: 45000, currency: 'PKR'),
      );
      expect(seeded.expression, '450');
      expect(seeded.toMoney('PKR'), const Money(minor: 45000, currency: 'PKR'));
    });
  });
}
