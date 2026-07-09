import 'package:intl/intl.dart';
import 'package:ledgr/core/money/money.dart';

/// Formats [Money] for display. The symbol is a presentation choice (set in
/// settings) independent of the ISO currency code stored on the amount.
class MoneyFormatter {
  const MoneyFormatter({required this.symbol, this.locale = 'en'});

  final String symbol;
  final String locale;

  String format(Money money) {
    final digits = money.decimalDigits;
    final pattern = NumberFormat.decimalPatternDigits(
      locale: locale,
      decimalDigits: digits,
    );
    final magnitude = money.toDecimal().abs().toDouble();
    final sign = money.isNegative ? '-' : '';
    return '$sign$symbol${pattern.format(magnitude)}';
  }
}
