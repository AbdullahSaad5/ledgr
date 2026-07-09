import 'package:flutter/material.dart';
import 'package:ledgr/app/theme/app_theme.dart';
import 'package:ledgr/core/db/database.dart';
import 'package:ledgr/core/db/enums.dart';
import 'package:ledgr/core/money/money.dart';
import 'package:ledgr/core/money/money_formatter.dart';
import 'package:ledgr/core/widgets/amount_text.dart';
import 'package:ledgr/core/widgets/app_icons.dart';
import 'package:ledgr/core/widgets/icon_badge.dart';

/// Compact account card showing icon, name, type, and current balance. Used in
/// the dashboard carousel and the accounts list.
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

  static const _typeLabels = {
    AccountType.cash: 'Cash',
    AccountType.bank: 'Bank',
    AccountType.creditCard: 'Credit card',
    AccountType.wallet: 'Wallet',
    AccountType.savings: 'Savings',
    AccountType.investment: 'Investment',
    AccountType.other: 'Account',
  };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final accent = Color(account.color);
    final balance = Money(minor: balanceMinor, currency: account.currency);
    final isDark = scheme.brightness == Brightness.dark;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: 190,
          padding: const EdgeInsets.all(Gaps.lg),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                accent.withValues(alpha: isDark ? 0.16 : 0.10),
                accent.withValues(alpha: 0.02),
              ],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  IconBadge(
                    icon: AppIcons.resolve(account.icon),
                    size: 36,
                    iconSize: 18,
                    background: accent.withValues(alpha: isDark ? 0.28 : 0.16),
                    color: isDark
                        ? Color.lerp(accent, Colors.white, 0.35)!
                        : Color.lerp(accent, Colors.black, 0.25)!,
                  ),
                  const SizedBox(width: Gaps.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          account.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.titleSmall,
                        ),
                        Text(
                          _typeLabels[account.type] ?? 'Account',
                          style: text.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Spacer(),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: AmountText(
                  balance,
                  formatter: formatter,
                  tone: balanceMinor < 0
                      ? AmountTone.expense
                      : AmountTone.neutral,
                  style: text.titleLarge,
                ),
              ),
              if (account.creditLimitMinor != null) ...[
                const SizedBox(height: Gaps.sm),
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
      borderRadius: BorderRadius.circular(99),
      child: LinearProgressIndicator(
        value: fraction,
        minHeight: 6,
        backgroundColor: track,
        color: fraction > 0.9 ? Theme.of(context).colorScheme.expense : color,
      ),
    );
  }
}
