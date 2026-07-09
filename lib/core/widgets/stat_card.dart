import 'package:flutter/material.dart';
import 'package:ledgr/app/theme/app_theme.dart';
import 'package:ledgr/core/money/money.dart';
import 'package:ledgr/core/money/money_formatter.dart';
import 'package:ledgr/core/widgets/amount_text.dart';

/// One labelled amount inside a [StatCard].
class StatItem {
  const StatItem({
    required this.label,
    required this.money,
    required this.tone,
  });

  final String label;
  final Money money;
  final AmountTone tone;
}

/// A card of 2–3 side-by-side money stats separated by hairlines
/// (e.g. Income / Expense / Net). The standard summary strip.
class StatCard extends StatelessWidget {
  const StatCard({required this.items, required this.formatter, super.key});

  final List<StatItem> items;
  final MoneyFormatter formatter;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Gaps.page,
        Gaps.xs,
        Gaps.page,
        Gaps.md,
      ),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: Gaps.lg),
          child: Row(
            children: [
              for (final (i, item) in items.indexed) ...[
                if (i > 0)
                  Container(width: 1, height: 30, color: scheme.outlineVariant),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        item.label,
                        style: text.labelMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 2),
                      AmountText(
                        item.money,
                        formatter: formatter,
                        tone: item.tone,
                        style: text.titleSmall,
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
