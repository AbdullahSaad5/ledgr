import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ledgr/app/theme/app_theme.dart';
import 'package:ledgr/core/time/period_resolver.dart';
import 'package:ledgr/core/widgets/soft_icon_button.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// The standard month/period navigator: chevrons flanking the period label.
/// Used by every screen that pages through reporting periods.
class PeriodSwitcher extends StatelessWidget {
  const PeriodSwitcher({
    required this.period,
    required this.onPrev,
    required this.onNext,
    super.key,
  });

  final Period period;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final label = DateFormat.yMMMM().format(
      DateTime(period.anchorYear, period.anchorMonth),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(Gaps.page, 0, Gaps.page, Gaps.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          SoftIconButton(
            icon: LucideIcons.chevronLeft,
            tooltip: 'Previous month',
            onPressed: onPrev,
          ),
          Text(label, style: Theme.of(context).textTheme.titleMedium),
          SoftIconButton(
            icon: LucideIcons.chevronRight,
            tooltip: 'Next month',
            onPressed: onNext,
          ),
        ],
      ),
    );
  }
}
