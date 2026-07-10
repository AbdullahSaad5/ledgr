import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ledgr/core/money/money.dart';

/// A text field for entering a major-unit amount, parsed to minor units.
/// Used for account opening balances and other non-keypad amount entry.
class MoneyField extends StatelessWidget {
  const MoneyField({
    required this.controller,
    required this.currency,
    this.label,
    this.symbol = '',
    super.key,
  });

  final TextEditingController controller;
  final String currency;
  final String? label;
  final String symbol;

  /// Parses the current text to [Money]; blank parses to zero.
  static Money parse(String text, String currency) {
    final cleaned = text.replaceAll(',', '').trim();
    if (cleaned.isEmpty) return Money.zero(currency);
    final value = Decimal.tryParse(cleaned) ?? Decimal.zero;
    return Money.fromDecimal(value, currency);
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[0-9.]'))],
      // No border override: inherits the app-wide filled field style.
      decoration: InputDecoration(
        labelText: label,
        prefixText: symbol.isEmpty ? null : symbol,
      ),
    );
  }
}
