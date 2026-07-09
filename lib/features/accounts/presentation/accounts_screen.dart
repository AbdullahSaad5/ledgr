import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ledgr/app/theme/app_theme.dart';
import 'package:ledgr/core/db/enums.dart';
import 'package:ledgr/core/money/money.dart';
import 'package:ledgr/core/providers/repository_providers.dart';
import 'package:ledgr/core/settings/settings_provider.dart';
import 'package:ledgr/core/widgets/amount_text.dart';
import 'package:ledgr/core/widgets/app_icons.dart';
import 'package:ledgr/core/widgets/empty_state.dart';
import 'package:ledgr/core/widgets/icon_badge.dart';
import 'package:ledgr/features/accounts/data/account_repository.dart';
import 'package:ledgr/features/accounts/presentation/account_form_sheet.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class AccountsScreen extends ConsumerWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountsAsync = ref.watch(activeAccountsProvider);
    final formatter = ref.watch(moneyFormatterProvider);
    final settings = ref.watch(appSettingsProvider);
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Accounts')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => AccountFormSheet.show(context),
        icon: const Icon(LucideIcons.plus),
        label: const Text('Account'),
      ),
      body: accountsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (accounts) {
          if (accounts.isEmpty) {
            return EmptyState(
              icon: LucideIcons.wallet,
              title: 'No accounts yet',
              message: 'Add cash, a bank, or a wallet to start tracking.',
              action: FilledButton.icon(
                onPressed: () => AccountFormSheet.show(context),
                icon: const Icon(LucideIcons.plus),
                label: const Text('Add account'),
              ),
            );
          }

          final netWorth = accounts
              .where((e) => e.account.includeInNetWorth)
              .fold(0, (sum, e) => sum + e.balanceMinor);
          final grouped = <AccountType, List<AccountWithBalance>>{};
          for (final e in accounts) {
            grouped.putIfAbsent(e.account.type, () => []).add(e);
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(
              Gaps.page,
              Gaps.xs,
              Gaps.page,
              96,
            ),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(Gaps.lg),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Net worth', style: text.titleSmall),
                      AmountText(
                        Money(minor: netWorth, currency: settings.homeCurrency),
                        formatter: formatter,
                        tone: AmountTone.auto,
                        style: text.titleLarge,
                      ),
                    ],
                  ),
                ),
              ),
              for (final type in grouped.keys) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(0, Gaps.xl, 0, Gaps.sm),
                  child: Text(
                    _typeLabel(type),
                    style: text.labelLarge?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      for (final (i, e) in grouped[type]!.indexed) ...[
                        if (i > 0)
                          Divider(
                            indent: Gaps.lg + 42 + Gaps.md,
                            color: scheme.outlineVariant,
                          ),
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: Gaps.lg,
                            vertical: 2,
                          ),
                          leading: IconBadge(
                            icon: AppIcons.resolve(e.account.icon),
                            color: Color(e.account.color),
                            iconSize: 19,
                          ),
                          title: Text(e.account.name),
                          trailing: AmountText(
                            Money(
                              minor: e.balanceMinor,
                              currency: e.account.currency,
                            ),
                            formatter: formatter,
                            tone: e.balanceMinor < 0
                                ? AmountTone.expense
                                : AmountTone.neutral,
                            style: text.titleSmall,
                          ),
                          onTap: () =>
                              context.push('/accounts/${e.account.id}'),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

String _typeLabel(AccountType t) => switch (t) {
  AccountType.cash => 'Cash',
  AccountType.bank => 'Bank',
  AccountType.creditCard => 'Credit cards',
  AccountType.wallet => 'Wallets',
  AccountType.savings => 'Savings',
  AccountType.investment => 'Investments',
  AccountType.other => 'Other',
};
