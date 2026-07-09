import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledgr/core/money/expression_evaluator.dart';

Decimal d(String s) => Decimal.parse(s);

void main() {
  group('ExpressionEvaluator — basic arithmetic', () {
    test('addition and subtraction, left to right', () {
      expect(ExpressionEvaluator.evaluate('1200+350'), d('1550'));
      expect(ExpressionEvaluator.evaluate('100+20+5'), d('125'));
      expect(ExpressionEvaluator.evaluate('5-8'), d('-3'));
      expect(ExpressionEvaluator.evaluate('100-30-30'), d('40'));
    });

    test('multiplication and division', () {
      expect(ExpressionEvaluator.evaluate('6*7'), d('42'));
      expect(ExpressionEvaluator.evaluate('10/4'), d('2.5'));
      expect(ExpressionEvaluator.evaluate('1/8'), d('0.125'));
    });

    test('decimals', () {
      expect(ExpressionEvaluator.evaluate('1.5+2.25'), d('3.75'));
      expect(ExpressionEvaluator.evaluate('0.1+0.2'), d('0.3'));
    });
  });

  group('ExpressionEvaluator — precedence', () {
    test('multiplication before addition', () {
      expect(ExpressionEvaluator.evaluate('2+3*4'), d('14'));
      expect(ExpressionEvaluator.evaluate('2*3+4'), d('10'));
      expect(ExpressionEvaluator.evaluate('100-10*3'), d('70'));
    });

    test('division before subtraction', () {
      expect(ExpressionEvaluator.evaluate('20-10/2'), d('15'));
    });
  });

  group('ExpressionEvaluator — normalization of unicode operators', () {
    test('accepts × ÷ − as * / -', () {
      expect(ExpressionEvaluator.evaluate('3×4'), d('12'));
      expect(ExpressionEvaluator.evaluate('12÷4'), d('3'));
      expect(ExpressionEvaluator.evaluate('9−4'), d('5'));
    });
  });

  group('ExpressionEvaluator — edge cases', () {
    test('single number', () {
      expect(ExpressionEvaluator.evaluate('1200'), d('1200'));
      expect(ExpressionEvaluator.evaluate('0'), d('0'));
    });

    test('leading negative', () {
      expect(ExpressionEvaluator.evaluate('-5'), d('-5'));
      expect(ExpressionEvaluator.evaluate('-5+8'), d('3'));
    });

    test('trailing operator is ignored (dangling on =)', () {
      expect(ExpressionEvaluator.evaluate('100+'), d('100'));
      expect(ExpressionEvaluator.evaluate('12*'), d('12'));
    });

    test('empty expression is zero', () {
      expect(ExpressionEvaluator.evaluate(''), d('0'));
      expect(ExpressionEvaluator.evaluate('   '), d('0'));
    });

    test('whitespace tolerated', () {
      expect(ExpressionEvaluator.evaluate(' 12 + 3 '), d('15'));
    });

    test('repeating division resolves to a bounded-scale decimal', () {
      final r = ExpressionEvaluator.evaluate('10/3');
      // Bounded scale, close to 3.333...
      expect(r.toDouble(), closeTo(3.3333333, 1e-6));
    });

    test('divide by zero throws', () {
      expect(
        () => ExpressionEvaluator.evaluate('5/0'),
        throwsA(isA<DivisionByZeroError>()),
      );
      expect(
        () => ExpressionEvaluator.evaluate('5/0+1'),
        throwsA(isA<DivisionByZeroError>()),
      );
    });
  });
}
