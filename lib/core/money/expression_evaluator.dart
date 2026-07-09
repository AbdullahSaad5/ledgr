import 'package:decimal/decimal.dart';

/// Thrown when an expression divides by zero.
class DivisionByZeroError extends Error {
  @override
  String toString() => 'DivisionByZeroError';
}

/// Thrown when an expression cannot be parsed.
class MalformedExpressionError extends Error {
  MalformedExpressionError(this.expression);
  final String expression;
  @override
  String toString() => 'MalformedExpressionError: "$expression"';
}

/// Evaluates the flat arithmetic expressions produced by the calculator keypad.
///
/// Supports `+ - * /` with standard precedence (`*`/`/` before `+`/`-`), decimal
/// literals, a leading unary minus, and a dangling trailing operator (ignored,
/// as a real calculator does when `=` is pressed mid-entry). All arithmetic is
/// on [Decimal] for exactness; division falls back to a bounded scale for
/// non-terminating results, which the caller rounds via `Money.fromDecimal`.
abstract final class ExpressionEvaluator {
  /// Scale used when a division does not terminate (e.g. 10/3).
  static const int _divisionScale = 12;

  static Decimal evaluate(String raw) {
    final tokens = _tokenize(raw);
    if (tokens.isEmpty) return Decimal.zero;
    return _evaluateTokens(tokens);
  }

  static List<_Token> _tokenize(String raw) {
    final normalized = raw
        .replaceAll('×', '*')
        .replaceAll('÷', '/')
        .replaceAll('−', '-')
        .replaceAll(' ', '');
    final tokens = <_Token>[];
    final number = StringBuffer();

    void flushNumber() {
      if (number.isNotEmpty) {
        tokens.add(_Token.number(Decimal.parse(number.toString())));
        number.clear();
      }
    }

    for (var i = 0; i < normalized.length; i++) {
      final ch = normalized[i];
      final isDigitOrDot = (ch.codeUnitAt(0) ^ 0x30) <= 9 || ch == '.';
      if (isDigitOrDot) {
        number.write(ch);
        continue;
      }
      if (ch == '+' || ch == '-' || ch == '*' || ch == '/') {
        // A '-' with no preceding number is a unary sign on the next number.
        if (ch == '-' && number.isEmpty && _expectsOperand(tokens)) {
          number.write('-');
          continue;
        }
        flushNumber();
        tokens.add(_Token.op(ch));
        continue;
      }
      throw MalformedExpressionError(raw);
    }
    flushNumber();

    // Drop a dangling trailing operator.
    if (tokens.isNotEmpty && tokens.last.isOperator) {
      tokens.removeLast();
    }
    return tokens;
  }

  /// True when the previous token is an operator (so a following `-` is unary)
  /// or there is no previous token at all (leading `-`).
  static bool _expectsOperand(List<_Token> tokens) =>
      tokens.isEmpty || tokens.last.isOperator;

  static Decimal _evaluateTokens(List<_Token> tokens) {
    if (!tokens.first.isNumber || !tokens.last.isNumber) {
      throw MalformedExpressionError(_render(tokens));
    }

    // First pass: resolve * and / left to right.
    final reduced = <_Token>[tokens.first];
    for (var i = 1; i < tokens.length; i += 2) {
      final op = tokens[i];
      final rhs = tokens[i + 1];
      if (!op.isOperator || !rhs.isNumber) {
        throw MalformedExpressionError(_render(tokens));
      }
      if (op.op == '*' || op.op == '/') {
        final lhs = reduced.removeLast();
        reduced.add(_Token.number(_apply(op.op!, lhs.value!, rhs.value!)));
      } else {
        reduced
          ..add(op)
          ..add(rhs);
      }
    }

    // Second pass: resolve + and - left to right.
    var acc = reduced.first.value!;
    for (var i = 1; i < reduced.length; i += 2) {
      final op = reduced[i].op!;
      final rhs = reduced[i + 1].value!;
      acc = _apply(op, acc, rhs);
    }
    return acc;
  }

  static Decimal _apply(String op, Decimal a, Decimal b) {
    switch (op) {
      case '+':
        return a + b;
      case '-':
        return a - b;
      case '*':
        return a * b;
      case '/':
        if (b == Decimal.zero) throw DivisionByZeroError();
        return (a / b).toDecimal(scaleOnInfinitePrecision: _divisionScale);
    }
    throw MalformedExpressionError(op);
  }

  static String _render(List<_Token> tokens) =>
      tokens.map((t) => t.op ?? '${t.value}').join();
}

class _Token {
  _Token.number(Decimal this.value) : op = null;
  _Token.op(String this.op) : value = null;

  final Decimal? value;
  final String? op;

  bool get isNumber => value != null;
  bool get isOperator => op != null;
}
