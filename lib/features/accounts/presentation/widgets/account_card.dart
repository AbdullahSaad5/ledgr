import 'package:flutter/material.dart';
import 'package:ledgr/core/db/database.dart';
import 'package:ledgr/core/money/money.dart';
import 'package:ledgr/core/money/money_formatter.dart';
import 'package:ledgr/core/widgets/amount_text.dart';
import 'package:ledgr/core/widgets/app_icons.dart';

/// Compact account tile showing icon, name, and current balance. Used in the
/// dashboard carousel and the accounts list.
class AccountCard extends StatelessWidget {
  const AccountCard({
    required this.account,
    required this.balanceMinor,
    required this.formatter,
    this.onTap,
    super.key,
  });

  final Account account;
  final int balanceMinor;
  final MoneyFormatter formatter;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = Color(account.color);
    final balance = Money(minor: balanceMinor, currency: account.currency);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: 180,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                accent.withValues(alpha: 0.18),
                accent.withValues(alpha: 0.04),
              ],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: accent.withValues(alpha: 0.9),
                child: Icon(
                  AppIcons.resolve(account.icon),
                  size: 18,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                account.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 4),
              AmountText(
                balance,
                formatter: formatter,
                tone: AmountTone.auto,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (account.creditLimitMinor != null) ...[
                const SizedBox(height: 8),
                _UtilizationBar(
                  balanceMinor: balanceMinor,
                  limitMinor: account.creditLimitMinor!,
                  color: accent,
                  track: scheme.surfaceContainerHighest,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _UtilizationBar extends StatelessWidget {
  const _UtilizationBar({
    required this.balanceMinor,
    required this.limitMinor,
    required this.color,
    required this.track,
  });

  final int balanceMinor;
  final int limitMinor;
  final Color color;
  final Color track;

  @override
  Widget build(BuildContext context) {
    // Credit card balances are negative when money is owed.
    final used = balanceMinor < 0 ? -balanceMinor : 0;
    final fraction = limitMinor == 0
        ? 0.0
        : (used / limitMinor).clamp(0.0, 1.0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: LinearProgressIndicator(
        value: fraction,
        minHeight: 6,
        backgroundColor: track,
        color: fraction > 0.9 ? Theme.of(context).colorScheme.error : color,
      ),
    );
  }
}
