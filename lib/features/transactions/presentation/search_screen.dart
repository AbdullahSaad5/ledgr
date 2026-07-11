import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledgr/core/db/enums.dart';
import 'package:ledgr/core/money/money.dart';
import 'package:ledgr/core/providers/repository_providers.dart';
import 'package:ledgr/core/settings/settings_provider.dart';
import 'package:ledgr/core/widgets/amount_text.dart';
import 'package:ledgr/core/widgets/empty_state.dart';
import 'package:ledgr/features/transactions/presentation/filter_sheet.dart';
import 'package:ledgr/features/transactions/presentation/transaction_detail_sheet.dart';
import 'package:ledgr/features/transactions/presentation/tx_actions.dart';
import 'package:ledgr/features/transactions/presentation/widgets/transaction_tile.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller.text = ref.read(transactionFilterProvider).text ?? '';
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final resultsAsync = ref.watch(filteredTransactionsProvider);
    final filter = ref.watch(transactionFilterProvider);
    final formatter = ref.watch(moneyFormatterProvider);
    final categories = ref.watch(categoryMapProvider);
    final accounts = ref.watch(accountMapProvider);
    final currency = ref.watch(appSettingsProvider).homeCurrency;

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Search payee or note',
            border: InputBorder.none,
          ),
          onChanged: (v) => ref.read(transactionFilterProvider.notifier).state =
              filter.copyWith(text: v),
        ),
        actions: [
          Badge(
            isLabelVisible: filter.activeCount > 0,
            label: Text('${filter.activeCount}'),
            child: IconButton(
              icon: const Icon(LucideIcons.slidersHorizontal, size: 20),
              onPressed: () => FilterSheet.show(context),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: resultsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (results) {
          if (results.isEmpty) {
            return const EmptyState(
              icon: LucideIcons.searchX,
              title: 'No matches',
              message: 'Try different text or adjust the filters.',
            );
          }
          final total = results.fold(0, (s, t) {
            if (t.type == TxType.income) return s + t.amountMinor;
            if (t.type == TxType.expense) return s - t.amountMinor;
            return s;
          });
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Text('${results.length} transactions'),
                    const SizedBox(width: 8),
                    // FittedBox: big totals at large font scales shrink to
                    // fit instead of overflowing the summary row.
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: AmountText(
                          Money(minor: total, currency: currency),
                          formatter: formatter,
                          tone: AmountTone.auto,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  itemCount: results.length,
                  itemBuilder: (context, i) {
                    final tx = results[i];
                    return TransactionTile(
                      transaction: tx,
                      formatter: formatter,
                      category: tx.categoryId == null
                          ? null
                          : categories[tx.categoryId],
                      accountName: accounts[tx.accountId]?.name,
                      onEdit: () => editTransaction(context, tx.id),
                      onDelete: () =>
                          deleteTransactionWithUndo(ref, context, tx.id),
                      onTap: () => TransactionDetailSheet.show(context, tx.id),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
