import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ledgr/core/db/enums.dart';
import 'package:ledgr/core/money/money.dart';
import 'package:ledgr/core/providers/repository_providers.dart';
import 'package:ledgr/core/settings/settings_provider.dart';
import 'package:ledgr/core/widgets/amount_text.dart';
import 'package:ledgr/core/widgets/app_icons.dart';
import 'package:ledgr/core/widgets/empty_state.dart';
import 'package:ledgr/features/accounts/data/account_repository.dart';
import 'package:ledgr/features/accounts/presentation/account_form_sheet.dart';

class AccountsScreen extends ConsumerWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountsAsync = ref.watch(activeAccountsProvider);
    final formatter = ref.watch(moneyFormatterProvider);
    final settings = ref.watch(appSettingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Accounts')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => AccountFormSheet.show(context),
        icon: const Icon(Icons.add),
        label: const Text('Account'),
      ),
      body: accountsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (accounts) {
          if (accounts.isEmpty) {
            return EmptyState(
              icon: Icons.account_balance_wallet_outlined,
              title: 'No accounts yet',
              message: 'Add cash, a bank, or a wallet to start tracking.',
              action: FilledButton.icon(
                onPressed: () => AccountFormSheet.show(context),
                icon: const Icon(Icons.add),
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
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Net worth',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    AmountText(
                      Money(minor: netWorth, currency: settings.homeCurrency),
                      formatter: formatter,
                      tone: AmountTone.auto,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ],
                ),
              ),
              for (final type in grouped.keys) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Text(
                    _typeLabel(type),
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                for (final e in grouped[type]!)
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Color(e.account.color),
                      child: Icon(
                        AppIcons.resolve(e.account.icon),
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    title: Text(e.account.name),
                    trailing: AmountText(
                      Money(
                        minor: e.balanceMinor,
                        currency: e.account.currency,
                      ),
                      formatter: formatter,
                      tone: AmountTone.auto,
                    ),
                    onTap: () => context.push('/accounts/${e.account.id}'),
                  ),
              ],
              const SizedBox(height: 80),
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
