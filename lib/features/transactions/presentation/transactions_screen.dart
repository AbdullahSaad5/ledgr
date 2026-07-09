import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:ledgr/core/db/database.dart';
import 'package:ledgr/core/db/enums.dart';
import 'package:ledgr/core/money/money.dart';
import 'package:ledgr/core/money/money_formatter.dart';
import 'package:ledgr/core/providers/repository_providers.dart';
import 'package:ledgr/core/settings/settings_provider.dart';
import 'package:ledgr/core/time/period_resolver.dart';
import 'package:ledgr/core/widgets/amount_text.dart';
import 'package:ledgr/core/widgets/empty_state.dart';
import 'package:ledgr/features/transactions/presentation/transaction_detail_sheet.dart';
import 'package:ledgr/features/transactions/presentation/widgets/transaction_tile.dart';

class TransactionsScreen extends ConsumerWidget {
  const TransactionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(selectedPeriodProvider);
    final resolver = ref.watch(periodResolverProvider);
    final txAsync = ref.watch(periodTransactionsProvider);
    final formatter = ref.watch(moneyFormatterProvider);
    final categories = ref.watch(categoryMapProvider);
    final accounts = ref.watch(accountMapProvider);
    final currency = ref.watch(appSettingsProvider).homeCurrency;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transactions'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: _MonthSwitcher(
            period: period,
            onPrev: () => ref.read(selectedPeriodProvider.notifier).state =
                resolver.previous(period),
            onNext: () => ref.read(selectedPeriodProvider.notifier).state =
                resolver.next(period),
          ),
        ),
      ),
      body: txAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (transactions) {
          if (transactions.isEmpty) {
            return const EmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'Nothing this month',
              message: 'Tap + to add your first transaction.',
            );
          }
          return _TransactionList(
            transactions: transactions,
            formatter: formatter,
            categories: categories,
            accounts: accounts,
            currency: currency,
          );
        },
      ),
    );
  }
}

class _MonthSwitcher extends StatelessWidget {
  const _MonthSwitcher({
    required this.period,
    required this.onPrev,
    required this.onNext,
  });

  final Period period;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final label = DateFormat.yMMMM().format(
      DateTime(period.anchorYear, period.anchorMonth),
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(icon: const Icon(Icons.chevron_left), onPressed: onPrev),
        SizedBox(
          width: 160,
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        IconButton(icon: const Icon(Icons.chevron_right), onPressed: onNext),
      ],
    );
  }
}

/// Signed effect of a transaction on income/expense totals (transfers net zero).
int _flowMinor(Transaction t) => switch (t.type) {
  TxType.income => t.amountMinor,
  TxType.expense => -t.amountMinor,
  TxType.adjustment => t.amountMinor,
  TxType.transfer => 0,
};

class _TransactionList extends StatelessWidget {
  const _TransactionList({
    required this.transactions,
    required this.formatter,
    required this.categories,
    required this.accounts,
    required this.currency,
  });

  final List<Transaction> transactions;
  final MoneyFormatter formatter;
  final Map<int, Category> categories;
  final Map<int, Account> accounts;
  final String currency;

  @override
  Widget build(BuildContext context) {
    // Group by calendar day (already sorted newest-first).
    final byDay = <DateTime, List<Transaction>>{};
    for (final t in transactions) {
      final day = DateTime(t.date.year, t.date.month, t.date.day);
      byDay.putIfAbsent(day, () => []).add(t);
    }

    var income = 0;
    var expense = 0;
    for (final t in transactions) {
      if (t.type == TxType.income) income += t.amountMinor;
      if (t.type == TxType.expense) expense += t.amountMinor;
    }

    final days = byDay.keys.toList();

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: _MonthSummary(
            incomeMinor: income,
            expenseMinor: expense,
            currency: currency,
            formatter: formatter,
          ),
        ),
        for (final day in days)
          SliverMainAxisGroup(
            slivers: [
              SliverToBoxAdapter(
                child: _DayHeader(
                  day: day,
                  netMinor: byDay[day]!.fold(0, (s, t) => s + _flowMinor(t)),
                  currency: currency,
                  formatter: formatter,
                ),
              ),
              SliverList.builder(
                itemCount: byDay[day]!.length,
                itemBuilder: (context, i) {
                  final tx = byDay[day]![i];
                  return TransactionTile(
                    transaction: tx,
                    formatter: formatter,
                    category: tx.categoryId == null
                        ? null
                        : categories[tx.categoryId],
                    accountName: accounts[tx.accountId]?.name,
                    onTap: () => TransactionDetailSheet.show(context, tx.id),
                  );
                },
              ),
            ],
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 80)),
      ],
    );
  }
}

class _MonthSummary extends StatelessWidget {
  const _MonthSummary({
    required this.incomeMinor,
    required this.expenseMinor,
    required this.currency,
    required this.formatter,
  });

  final int incomeMinor;
  final int expenseMinor;
  final String currency;
  final MoneyFormatter formatter;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _stat(
            context,
            'Income',
            Money(minor: incomeMinor, currency: currency),
            AmountTone.income,
          ),
          _stat(
            context,
            'Expense',
            Money(minor: expenseMinor, currency: currency),
            AmountTone.expense,
          ),
          _stat(
            context,
            'Net',
            Money(minor: incomeMinor - expenseMinor, currency: currency),
            AmountTone.auto,
          ),
        ],
      ),
    );
  }

  Widget _stat(
    BuildContext context,
    String label,
    Money money,
    AmountTone tone,
  ) {
    return Column(
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 2),
        AmountText(money, formatter: formatter, tone: tone),
      ],
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({
    required this.day,
    required this.netMinor,
    required this.currency,
    required this.formatter,
  });

  final DateTime day;
  final int netMinor;
  final String currency;
  final MoneyFormatter formatter;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            DateFormat('EEE, d MMM').format(day),
            style: Theme.of(context).textTheme.labelLarge,
          ),
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
