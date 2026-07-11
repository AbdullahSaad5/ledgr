import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ledgr/app/theme/app_theme.dart';
import 'package:ledgr/core/money/money.dart';
import 'package:ledgr/core/money/money_formatter.dart';
import 'package:ledgr/core/widgets/amount_text.dart';

/// A quiet day-group header for transaction lists: date on the left, the
/// day's net effect on the right.
class DayHeader extends StatelessWidget {
  const DayHeader({
    required this.day,
    required this.netMinor,
    required this.currency,
    required this.formatter,
    super.key,
  });

  final DateTime day;
  final int netMinor;
  final String currency;
  final MoneyFormatter formatter;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Gaps.page, Gaps.md, Gaps.page, 4),
      child: Row(
        children: [
          // Expanded + ellipsis so a large day total at a big font scale
          // squeezes the date instead of overflowing the row.
          Expanded(
            child: Text(
              DateFormat('EEE, d MMM').format(day),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
          const SizedBox(width: Gaps.sm),
          AmountText(
            Money(minor: netMinor, currency: currency),
            formatter: formatter,
            tone: AmountTone.auto,
            style: Theme.of(context).textTheme.labelMedium,
          ),
        ],
      ),
    );
  }
}
