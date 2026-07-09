import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledgr/app/theme/app_theme.dart';
import 'package:ledgr/core/money/money.dart';
import 'package:ledgr/core/providers/repository_providers.dart';
import 'package:ledgr/core/settings/settings_provider.dart';
import 'package:ledgr/core/widgets/animated_amount.dart';
import 'package:ledgr/core/widgets/app_icons.dart';
import 'package:ledgr/core/widgets/empty_state.dart';
import 'package:ledgr/core/widgets/icon_badge.dart';
import 'package:ledgr/core/widgets/menu_sheet.dart';
import 'package:ledgr/features/accounts/presentation/account_form_sheet.dart';
import 'package:ledgr/features/accounts/presentation/reconcile_sheet.dart';
import 'package:ledgr/features/transactions/presentation/transaction_detail_sheet.dart';
import 'package:ledgr/features/transactions/presentation/tx_actions.dart';
import 'package:ledgr/features/transactions/presentation/widgets/transaction_tile.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

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
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

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
                icon: const Icon(LucideIcons.pencil, size: 20),
                tooltip: 'Edit account',
                onPressed: () =>
                    AccountFormSheet.show(context, account: account),
              ),
              IconButton(
                icon: const Icon(LucideIcons.moreVertical, size: 20),
                tooltip: 'More',
                onPressed: () => MenuSheet.show(
                  context,
                  title: account.name,
                  items: [
                    MenuSheetItem(
                      icon: LucideIcons.scale,
                      label: 'Reconcile',
                      subtitle: 'Match the balance to real life',
                      onTap: () => ReconcileSheet.show(
                        context,
                        account: account,
                        currentMinor: balanceMinor,
                      ),
                    ),
                    MenuSheetItem(
                      icon: LucideIcons.archive,
                      label: 'Archive',
                      subtitle: 'Hide without deleting history',
                      onTap: () async {
                        await ref
                            .read(accountRepositoryProvider)
                            .setArchived(account.id, archived: true);
                        if (context.mounted) Navigator.of(context).pop();
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Gaps.page,
                  Gaps.xs,
                  Gaps.page,
                  Gaps.lg,
                ),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(Gaps.xl),
                  decoration: ShapeDecoration(
                    shape: RoundedSuperellipseBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: scheme.heroGradient,
                    ),
                  ),
                  child: Row(
                    children: [
                      IconBadge(
                        icon: AppIcons.resolve(account.icon),
                        color: Colors.white,
                        size: 44,
                        iconSize: 20,
                        background: Colors.white.withValues(alpha: 0.12),
                      ),
                      const SizedBox(width: Gaps.lg),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Balance',
                            style: text.labelMedium?.copyWith(
                              color: scheme.onHeroMuted,
                            ),
                          ),
                          AnimatedAmount(
                            Money(
                              minor: balanceMinor,
                              currency: account.currency,
                            ),
                            formatter: formatter,
                            style: text.headlineMedium?.copyWith(
                              color: scheme.onHero,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: historyAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('$e')),
                  data: (history) {
                    if (history.isEmpty) {
                      return const EmptyState(
                        icon: LucideIcons.receipt,
                        title: 'No transactions',
                        message: 'Activity on this account shows up here.',
                      );
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.only(bottom: Gaps.xxl),
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
                          onEdit: () => editTransaction(context, tx.id),
                          onDelete: () =>
                              deleteTransactionWithUndo(ref, context, tx.id),
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
