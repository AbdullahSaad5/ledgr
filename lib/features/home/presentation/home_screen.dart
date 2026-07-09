import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ledgr/core/money/money.dart';
import 'package:ledgr/core/money/money_formatter.dart';
import 'package:ledgr/core/providers/repository_providers.dart';
import 'package:ledgr/core/settings/settings_provider.dart';
import 'package:ledgr/core/widgets/amount_text.dart';
import 'package:ledgr/features/accounts/presentation/account_form_sheet.dart';
import 'package:ledgr/features/accounts/presentation/widgets/account_card.dart';
import 'package:ledgr/features/transactions/presentation/transaction_detail_sheet.dart';
import 'package:ledgr/features/transactions/presentation/widgets/transaction_tile.dart';
import 'package:ledgr/l10n/generated/app_localizations.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppL10n.of(context);
    final formatter = ref.watch(moneyFormatterProvider);
    final currency = ref.watch(appSettingsProvider).homeCurrency;
    final accountsAsync = ref.watch(activeAccountsProvider);
    final netWorth = ref.watch(netWorthProvider).valueOrNull ?? 0;
    final recent =
        ref.watch(periodTransactionsProvider).valueOrNull ?? const [];
    final categories = ref.watch(categoryMapProvider);
    final accountMap = ref.watch(accountMapProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.dashboardTitle)),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.netWorthLabel,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                AmountText(
                  Money(minor: netWorth, currency: currency),
                  formatter: formatter,
                  tone: AmountTone.auto,
                  style: Theme.of(context).textTheme.displaySmall,
                ),
              ],
            ),
          ),
          SizedBox(
            height: 172,
            child: accountsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('$e')),
              data: (accounts) => ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  for (final e in accounts)
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: AccountCard(
                        account: e.account,
                        balanceMinor: e.balanceMinor,
                        formatter: formatter,
                        onTap: () => context.push('/accounts/${e.account.id}'),
                      ),
                    ),
                  _AddAccountCard(onTap: () => AccountFormSheet.show(context)),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Accounts',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                TextButton(
                  onPressed: () => context.push('/accounts'),
                  child: const Text('See all'),
                ),
              ],
            ),
          ),
          _BudgetsSnapshot(formatter: formatter, currency: currency),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 12, 0),
            child: Text(
              'Recent',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          if (recent.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: Text('No transactions yet')),
            )
          else
            for (final tx in recent.take(6))
              TransactionTile(
                transaction: tx,
                formatter: formatter,
                category: tx.categoryId == null
                    ? null
                    : categories[tx.categoryId],
                accountName: accountMap[tx.accountId]?.name,
                onTap: () => TransactionDetailSheet.show(context, tx.id),
              ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

class _BudgetsSnapshot extends ConsumerWidget {
  const _BudgetsSnapshot({required this.formatter, required this.currency});

  final MoneyFormatter formatter;
  final String currency;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(budgetProgressProvider).valueOrNull ?? const [];
    if (progress.isEmpty) return const SizedBox.shrink();
    final top = [...progress]..sort((a, b) => b.fraction.compareTo(a.fraction));
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 12, 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Budgets', style: Theme.of(context).textTheme.titleMedium),
              TextButton(
                onPressed: () => context.push('/budgets'),
                child: const Text('See all'),
              ),
            ],
          ),
        ),
        for (final p in top.take(3))
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: p.fraction,
                      minHeight: 8,
                      backgroundColor: scheme.surfaceContainerHighest,
                      color: p.fraction >= 1.0
                          ? scheme.error
                          : p.fraction >= 0.8
                          ? Colors.orange
                          : scheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text('${(p.fraction * 100).round()}%'),
              ],
            ),
          ),
      ],
    );
  }
}

class _AddAccountCard extends StatelessWidget {
  const _AddAccountCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 130,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add, color: scheme.primary),
              const SizedBox(height: 8),
              const Text('Add account'),
            ],
          ),
        ),
      ),
    );
  }
}
