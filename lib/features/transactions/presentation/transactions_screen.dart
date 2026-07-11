import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ledgr/app/theme/app_theme.dart';
import 'package:ledgr/app/widgets/ledgr_nav_bar.dart';
import 'package:ledgr/core/db/database.dart';
import 'package:ledgr/core/db/enums.dart';
import 'package:ledgr/core/money/money.dart';
import 'package:ledgr/core/money/money_formatter.dart';
import 'package:ledgr/core/providers/repository_providers.dart';
import 'package:ledgr/core/settings/settings_provider.dart';
import 'package:ledgr/core/widgets/amount_text.dart';
import 'package:ledgr/core/widgets/app_icons.dart';
import 'package:ledgr/core/widgets/day_header.dart';
import 'package:ledgr/core/widgets/empty_state.dart';
import 'package:ledgr/core/widgets/icon_badge.dart';
import 'package:ledgr/core/widgets/ledgr_header.dart';
import 'package:ledgr/core/widgets/menu_sheet.dart';
import 'package:ledgr/core/widgets/period_switcher.dart';
import 'package:ledgr/core/widgets/soft_icon_button.dart';
import 'package:ledgr/core/widgets/stat_card.dart';
import 'package:ledgr/features/transactions/presentation/transaction_detail_sheet.dart';
import 'package:ledgr/features/transactions/presentation/tx_actions.dart';
import 'package:ledgr/features/transactions/presentation/widgets/transaction_tile.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

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
    final selection = ref.watch(selectedTransactionsProvider);
    final selecting = selection.isNotEmpty;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            if (selecting)
              _SelectionHeader(selection: selection)
            else
              LedgrHeader(
                title: 'Transactions',
                actions: [
                  SoftIconButton(
                    icon: LucideIcons.search,
                    tooltip: 'Search',
                    onPressed: () => context.push('/search'),
                  ),
                  SoftIconButton(
                    icon: LucideIcons.moreVertical,
                    tooltip: 'More',
                    onPressed: () => MenuSheet.show(
                      context,
                      items: [
                        MenuSheetItem(
                          icon: LucideIcons.shapes,
                          label: 'Manage categories',
                          onTap: () => context.push('/categories'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            PeriodSwitcher(
              period: period,
              onPrev: () => ref.read(selectedPeriodProvider.notifier).state =
                  resolver.previous(period),
              onNext: () => ref.read(selectedPeriodProvider.notifier).state =
                  resolver.next(period),
            ),
            Expanded(
              child: txAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('$e')),
                data: (transactions) {
                  if (transactions.isEmpty) {
                    return const EmptyState(
                      icon: LucideIcons.receipt,
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
            ),
          ],
        ),
      ),
    );
  }
}

/// Contextual header shown while transactions are multi-selected.
class _SelectionHeader extends ConsumerWidget {
  const _SelectionHeader({required this.selection});

  final Set<int> selection;

  void _clear(WidgetRef ref) =>
      ref.read(selectedTransactionsProvider.notifier).state = {};

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Gaps.md, Gaps.md, Gaps.lg, Gaps.md),
      child: Row(
        children: [
          SoftIconButton(
            icon: LucideIcons.x,
            tooltip: 'Clear selection',
            onPressed: () => _clear(ref),
          ),
          const SizedBox(width: Gaps.sm),
          Expanded(
            child: Text(
              '${selection.length} selected',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          SoftIconButton(
            icon: LucideIcons.tag,
            tooltip: 'Re-categorize',
            onPressed: () async {
              final categoryId = await _pickCategoryForBulk(context, ref);
              if (categoryId == null) return;
              final repo = ref.read(transactionRepositoryProvider);
              for (final id in selection) {
                await repo.setCategory(id, categoryId);
              }
              _clear(ref);
            },
          ),
          SoftIconButton(
            icon: LucideIcons.trash2,
            tooltip: 'Delete',
            onPressed: () async {
              final repo = ref.read(transactionRepositoryProvider);
              final ids = selection.toList();
              final messenger = ScaffoldMessenger.of(context);
              for (final id in ids) {
                await repo.softDelete(id);
              }
              _clear(ref);
              messenger.showSnackBar(
                SnackBar(
                  content: Text('${ids.length} deleted'),
                  action: SnackBarAction(
                    label: 'Undo',
                    onPressed: () async {
                      for (final id in ids) {
                        await repo.restore(id);
                      }
                    },
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  /// Parents in position order, each directly followed by its children, so
  /// the sheet reads as a hierarchy rather than a flat mixed list.
  static List<Category> _grouped(List<Category> categories) {
    final childrenOf = <int, List<Category>>{};
    for (final c in categories) {
      final p = c.parentId;
      if (p != null) childrenOf.putIfAbsent(p, () => []).add(c);
    }
    return [
      for (final parent in categories.where((c) => c.parentId == null)) ...[
        parent,
        ...childrenOf[parent.id] ?? const <Category>[],
      ],
    ];
  }

  Future<int?> _pickCategoryForBulk(BuildContext context, WidgetRef ref) {
    // Watch inside the sheet: a one-shot read before the stream's first
    // emission returns loading and the sheet stays empty forever.
    return showModalBottomSheet<int>(
      context: context,
      useRootNavigator: true,
      builder: (sheetContext) => SafeArea(
        child: Consumer(
          builder: (context, ref, _) {
            // A selection can mix incomes and expenses, so offer both kinds.
            final expense =
                ref
                    .watch(categoriesByKindProvider(CategoryKind.expense))
                    .valueOrNull ??
                const <Category>[];
            final income =
                ref
                    .watch(categoriesByKindProvider(CategoryKind.income))
                    .valueOrNull ??
                const <Category>[];
            if (expense.isEmpty && income.isEmpty) {
              return const SizedBox(
                height: 180,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final byId = {
              for (final c in [...expense, ...income]) c.id: c,
            };
            Widget tile(Category c) => ListTile(
              contentPadding: EdgeInsets.only(
                left: c.parentId == null ? 16 : 32,
                right: 16,
              ),
              leading: IconBadge(
                icon: AppIcons.resolve(c.icon),
                color: Color(c.color),
                size: 38,
                iconSize: 18,
              ),
              title: Text(
                c.parentId == null
                    ? c.name
                    : '${byId[c.parentId]?.name ?? '?'} > ${c.name}',
              ),
              onTap: () => Navigator.of(context).pop(c.id),
            );
            Widget header(String label) => Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            );
            return ListView(
              shrinkWrap: true,
              children: [
                if (expense.isNotEmpty) header('Expense'),
                for (final c in _grouped(expense)) tile(c),
                if (income.isNotEmpty) header('Income'),
                for (final c in _grouped(income)) tile(c),
              ],
            );
          },
        ),
      ),
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

class _TransactionList extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final selection = ref.watch(selectedTransactionsProvider);
    final selecting = selection.isNotEmpty;

    void toggle(int id) {
      final next = {...selection};
      if (next.contains(id)) {
        next.remove(id);
      } else {
        next.add(id);
      }
      ref.read(selectedTransactionsProvider.notifier).state = next;
    }

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
          child: StatCard(
            formatter: formatter,
            items: [
              StatItem(
                label: 'Income',
                money: Money(minor: income, currency: currency),
                tone: AmountTone.income,
              ),
              StatItem(
                label: 'Expense',
                money: Money(minor: expense, currency: currency),
                tone: AmountTone.expense,
              ),
              StatItem(
                label: 'Net',
                money: Money(minor: income - expense, currency: currency),
                tone: AmountTone.auto,
              ),
            ],
          ),
        ),
        for (final day in days)
          SliverMainAxisGroup(
            slivers: [
              SliverToBoxAdapter(
                child: DayHeader(
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
                    selected: selection.contains(tx.id),
                    onLongPress: () => toggle(tx.id),
                    onEdit: () => editTransaction(context, tx.id),
                    onDelete: () =>
                        deleteTransactionWithUndo(ref, context, tx.id),
                    onTap: selecting
                        ? () => toggle(tx.id)
                        : () => TransactionDetailSheet.show(context, tx.id),
                  );
                },
              ),
            ],
          ),
        SliverToBoxAdapter(
          child: SizedBox(height: LedgrNavBar.clearanceOf(context)),
        ),
      ],
    );
  }
}
