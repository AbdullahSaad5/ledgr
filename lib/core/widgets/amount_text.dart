import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledgr/app/theme/app_theme.dart';
import 'package:ledgr/core/money/money.dart';
import 'package:ledgr/core/money/money_formatter.dart';
import 'package:ledgr/core/settings/settings_provider.dart';

/// How an amount should be tinted.
enum AmountTone { neutral, income, expense, auto }

/// Renders a [Money] value with tabular figures and optional semantic colour.
/// `auto` derives the colour from the sign. Respects the global amount-blur
/// privacy toggle.
class AmountText extends ConsumerWidget {
  const AmountText(
    this.money, {
    required this.formatter,
    this.tone = AmountTone.neutral,
    this.style,
    this.showPlus = false,
    super.key,
  });

  final Money money;
  final MoneyFormatter formatter;
  final AmountTone tone;
  final TextStyle? style;
  final bool showPlus;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hidden = ref.watch(
      appSettingsProvider.select((s) => s.amountsHidden),
    );
    final scheme = Theme.of(context).colorScheme;
    final color = switch (tone) {
      AmountTone.neutral => null,
      AmountTone.income => scheme.income,
      AmountTone.expense => scheme.expense,
      AmountTone.auto => money.isNegative ? scheme.expense : scheme.income,
    };
    final prefix = showPlus && money.isPositive ? '+' : '';
    final text = hidden ? '••••' : '$prefix${formatter.format(money)}';
    final toneLabel = switch (tone) {
      AmountTone.income => 'income, ',
      AmountTone.expense => 'expense, ',
      _ => '',
    };
    return Text(
      text,
      semanticsLabel: hidden ? 'Amount hidden' : '$toneLabel$text',
      style: (style ?? DefaultTextStyle.of(context).style).copyWith(
        color: color,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}
