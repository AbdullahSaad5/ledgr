import 'package:decimal/decimal.dart';
import 'package:ledgr/core/money/expression_evaluator.dart';
import 'package:ledgr/core/money/money.dart';

/// Mutable input state for the calculator keypad (PLAN.md §6.3).
///
/// Holds the raw expression string, enforces sane entry rules (one decimal per
/// number segment, no leading binary operator, operator replacement), and
/// evaluates to a [Decimal]/[Money] via [ExpressionEvaluator].
class KeypadController {
  KeypadController([this.expression = '']);

  /// Seed the keypad from an existing amount for the edit flow.
  factory KeypadController.fromMoney(Money money) {
    final text = money.toDecimal().toString();
    return KeypadController(text);
  }

  /// The raw expression string being built.
  String expression;

  bool get isEmpty => expression.isEmpty;

  static const _operators = {'+', '-', '*', '/'};

  void pressDigit(String digit) {
    assert(digit.length == 1 && '0123456789'.contains(digit), 'not a digit');
    expression += digit;
  }

  void pressDecimal() {
    final segment = _currentSegment();
    if (segment.contains('.')) return; // one decimal per number
    if (segment.isEmpty) {
      expression += '0.';
    } else {
      expression += '.';
    }
  }

  void pressOperator(String op) {
    assert(_operators.contains(op), 'not an operator');
    if (expression.isEmpty) {
      // Only a leading minus (negative number) is meaningful.
      if (op == '-') expression = '-';
      return;
    }
    // Trim a dangling decimal point before appending an operator.
    if (expression.endsWith('.')) {
      expression = expression.substring(0, expression.length - 1);
    }
    if (_endsWithOperator()) {
      // Replace the trailing operator.
      expression = expression.substring(0, expression.length - 1) + op;
    } else {
      expression += op;
    }
  }

  void backspace() {
    if (expression.isEmpty) return;
    expression = expression.substring(0, expression.length - 1);
  }

  void clear() => expression = '';

  Decimal evaluate() => ExpressionEvaluator.evaluate(expression);

  Money toMoney(String currency) => Money.fromDecimal(evaluate(), currency);

  /// Evaluate to [Money], returning zero on an incomplete/invalid expression
  /// (e.g. mid-entry, or divide-by-zero). For live display use.
  Money toMoneyOrZero(String currency) {
    try {
      return toMoney(currency);
    } on Object {
      return Money.zero(currency);
    }
  }

  bool _endsWithOperator() =>
      expression.isNotEmpty &&
      _operators.contains(expression[expression.length - 1]);

  /// The trailing run of number characters (digits and the decimal point).
  String _currentSegment() {
    var i = expression.length;
    while (i > 0) {
      final ch = expression[i - 1];
      final isNumberChar = ch == '.' || '0123456789'.contains(ch);
      if (!isNumberChar) break;
      i--;
    }
    return expression.substring(i);
  }
}
