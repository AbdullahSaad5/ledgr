import 'package:decimal/decimal.dart';
import 'package:ledgr/core/money/expression_evaluator.dart';
import 'package:ledgr/core/money/money.dart';

/// Mutable input state for the calculator keypad (PLAN.md §6.3).
///
/// Holds the raw expression string, enforces sane entry rules (one decimal per
/// number segment, no leading binary operator, operator replacement), and
/// evaluates to a [Decimal]/[Money] via [ExpressionEvaluator].
class KeypadController {
  KeypadController([String initial = '']) : _expression = initial;

  /// Seed the keypad from an existing amount for the edit flow.
  factory KeypadController.fromMoney(Money money) {
    final text = money.toDecimal().toString();
    return KeypadController(text);
  }

  String _expression;

  String get expression => _expression;
  bool get isEmpty => _expression.isEmpty;

  static const _operators = {'+', '-', '*', '/'};

  void pressDigit(String digit) {
    assert(digit.length == 1 && '0123456789'.contains(digit), 'not a digit');
    _expression += digit;
  }

  void pressDecimal() {
    final segment = _currentSegment();
    if (segment.contains('.')) return; // one decimal per number
    if (segment.isEmpty) {
      _expression += '0.';
    } else {
      _expression += '.';
    }
  }

  void pressOperator(String op) {
    assert(_operators.contains(op), 'not an operator');
    if (_expression.isEmpty) {
      // Only a leading minus (negative number) is meaningful.
      if (op == '-') _expression = '-';
      return;
    }
    // Trim a dangling decimal point before appending an operator.
    if (_expression.endsWith('.')) {
      _expression = _expression.substring(0, _expression.length - 1);
    }
    if (_endsWithOperator()) {
      // Replace the trailing operator.
      _expression = _expression.substring(0, _expression.length - 1) + op;
    } else {
      _expression += op;
    }
  }

  void backspace() {
    if (_expression.isEmpty) return;
    _expression = _expression.substring(0, _expression.length - 1);
  }

  void clear() => _expression = '';

  Decimal evaluate() => ExpressionEvaluator.evaluate(_expression);

  Money toMoney(String currency) => Money.fromDecimal(evaluate(), currency);

  bool _endsWithOperator() =>
      _expression.isNotEmpty &&
      _operators.contains(_expression[_expression.length - 1]);

  /// The trailing run of number characters (digits and the decimal point).
  String _currentSegment() {
    var i = _expression.length;
    while (i > 0) {
      final ch = _expression[i - 1];
      final isNumberChar = ch == '.' || '0123456789'.contains(ch);
      if (!isNumberChar) break;
      i--;
    }
    return _expression.substring(i);
  }
}
