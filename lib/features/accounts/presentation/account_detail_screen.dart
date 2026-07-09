import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledgr/core/money/money.dart';
import 'package:ledgr/core/providers/repository_providers.dart';
import 'package:ledgr/core/settings/settings_provider.dart';
import 'package:ledgr/core/widgets/amount_text.dart';
import 'package:ledgr/core/widgets/empty_state.dart';
import 'package:ledgr/features/accounts/presentation/account_form_sheet.dart';
import 'package:ledgr/features/accounts/presentation/reconcile_sheet.dart';
import 'package:ledgr/features/transactions/presentation/transaction_detail_sheet.dart';
import 'package:ledgr/features/transactions/presentation/widgets/transaction_tile.dart';

class AccountDetailScreen extends ConsumerWidget {
  const AccountDetailScreen({required this.accountId, super.key});

  final int accountId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountAsync = ref.watch(accountByIdProvider(accountId));
    final balanceAsync = ref.watch(accountBalanceProvider(accountId));
    final historyAsync = ref.watch(accountHistoryProvider(accountId));
    final formatter = ref.watch(moneyFormatterProvider);
    final categories = ref.watch(categoryMapProvider);

    return accountAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('$e'))),
      data: (account) {
        final balanceMinor = balanceAsync.valueOrNull ?? 0;
        return Scaffold(
          appBar: AppBar(
            title: Text(account.name),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                onPressed: () =>
                    AccountFormSheet.show(context, account: account),
              ),
              PopupMenuButton<String>(
                onSelected: (v) async {
                  if (v == 'reconcile') {
                    await ReconcileSheet.show(
                      context,
                      account: account,
                      currentMinor: balanceMinor,
                    );
                  } else if (v == 'archive') {
                    await ref
                        .read(accountRepositoryProvider)
                        .setArchived(account.id, archived: true);
                    if (context.mounted) Navigator.of(context).pop();
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'reconcile', child: Text('Reconcile')),
                  PopupMenuItem(value: 'archive', child: Text('Archive')),
                ],
              ),
            ],
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Text(
                      'Balance',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    AmountText(
                      Money(minor: balanceMinor, currency: account.currency),
                      formatter: formatter,
                      tone: AmountTone.auto,
                      style: Theme.of(context).textTheme.displaySmall,
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: historyAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('$e')),
                  data: (history) {
                    if (history.isEmpty) {
                      return const EmptyState(
                        icon: Icons.receipt_long_outlined,
                        title: 'No transactions',
                        message: 'Activity on this account shows up here.',
                      );
                    }
                    return ListView.builder(
                      itemCount: history.length,
                      itemBuilder: (context, i) {
                        final tx = history[i];
                        return TransactionTile(
                          transaction: tx,
                          formatter: formatter,
                          category: tx.categoryId == null
                              ? null
                              : categories[tx.categoryId],
                          perspectiveAccountId: accountId,
                          onTap: () =>
                              TransactionDetailSheet.show(context, tx.id),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
