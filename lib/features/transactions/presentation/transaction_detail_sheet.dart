import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:ledgr/app/theme/app_theme.dart';
import 'package:ledgr/core/db/enums.dart';
import 'package:ledgr/core/money/money_x.dart';
import 'package:ledgr/core/providers/repository_providers.dart';
import 'package:ledgr/core/settings/settings_provider.dart';
import 'package:ledgr/core/widgets/amount_text.dart';
import 'package:ledgr/core/widgets/app_icons.dart';
import 'package:ledgr/core/widgets/icon_badge.dart';
import 'package:ledgr/features/transactions/presentation/tx_actions.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Read-only transaction detail with edit / duplicate / delete actions.
class TransactionDetailSheet extends ConsumerWidget {
  const TransactionDetailSheet({required this.transactionId, super.key});

  final int transactionId;

  static Future<void> show(BuildContext context, int id) {
    return showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => TransactionDetailSheet(transactionId: id),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final txAsync = ref.watch(transactionByIdProvider(transactionId));
    final formatter = ref.watch(moneyFormatterProvider);
    final categories = ref.watch(categoryMapProvider);
    final accounts = ref.watch(accountMapProvider);
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return txAsync.when(
      loading: () => const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => SizedBox(height: 200, child: Center(child: Text('$e'))),
      data: (tx) {
        final category = tx.categoryId == null
            ? null
            : categories[tx.categoryId];
        final (IconData icon, Color tint, String title) = switch (tx.type) {
          TxType.transfer => (
            LucideIcons.arrowLeftRight,
            scheme.transfer,
            tx.payee ?? 'Transfer',
          ),
          TxType.adjustment => (
            LucideIcons.slidersHorizontal,
            scheme.onSurfaceVariant,
            tx.note ?? 'Adjustment',
          ),
          _ => (
            AppIcons.resolve(category?.icon ?? 'category'),
            category == null ? scheme.onSurfaceVariant : Color(category.color),
            tx.payee ?? category?.name ?? 'Transaction',
          ),
        };
        final tone = switch (tx.type) {
          TxType.income => AmountTone.income,
          TxType.expense => AmountTone.expense,
          _ => AmountTone.neutral,
        };
        final accountLabel = tx.type == TxType.transfer
            ? '${accounts[tx.accountId]?.name ?? 'Account'} → '
                  '${accounts[tx.toAccountId]?.name ?? 'Account'}'
            : accounts[tx.accountId]?.name ?? 'Account';

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(Gaps.page, 0, Gaps.page, Gaps.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconBadge(icon: icon, color: tint, size: 56, iconSize: 24),
              const SizedBox(height: Gaps.md),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: AmountText(
                  tx.amount,
                  formatter: formatter,
                  tone: tone,
                  showPlus: tx.type == TxType.income,
                  style: text.headlineMedium,
                ),
              ),
              Text(
                title,
                style: text.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: Gaps.xl),
              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Gaps.lg,
                    vertical: Gaps.sm,
                  ),
                  child: Column(
                    children: [
                      _row(
                        context,
                        LucideIcons.wallet,
                        tx.type == TxType.transfer ? 'Between' : 'Account',
                        accountLabel,
                      ),
                      if (category != null)
                        _row(
                          context,
                          LucideIcons.shapes,
                          'Category',
                          category.name,
                        ),
                      _row(
                        context,
                        LucideIcons.calendar,
                        'Date',
                        DateFormat('EEE, d MMM yyyy').format(tx.date),
                      ),
                      if (tx.fee != null && tx.fee!.minor > 0)
                        _row(
                          context,
                          LucideIcons.receipt,
                          'Fee',
                          formatter.format(tx.fee!),
                        ),
                      if (tx.note != null && tx.note!.isNotEmpty)
                        _row(
                          context,
                          LucideIcons.notebookPen,
                          'Note',
                          tx.note!,
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: Gaps.lg),
              Row(
                children: [
                  _ActionTile(
                    icon: LucideIcons.pencil,
                    label: 'Edit',
                    onTap: () {
                      Navigator.of(context).pop();
                      editTransaction(context, tx.id);
                    },
                  ),
                  const SizedBox(width: Gaps.sm),
                  _ActionTile(
                    icon: LucideIcons.copy,
                    label: 'Duplicate',
                    onTap: () async {
                      await ref
                          .read(transactionRepositoryProvider)
                          .duplicate(tx.id);
                      if (context.mounted) Navigator.of(context).pop();
                    },
                  ),
                  const SizedBox(width: Gaps.sm),
                  _ActionTile(
                    icon: LucideIcons.trash2,
                    label: 'Delete',
                    destructive: true,
                    onTap: () async {
                      Navigator.of(context).pop();
                      await deleteTransactionWithUndo(ref, context, tx.id);
                    },
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _row(BuildContext context, IconData icon, String label, String value) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Gaps.sm),
      child: Row(
        children: [
          Icon(icon, size: 16, color: scheme.onSurfaceVariant),
          const SizedBox(width: Gaps.md),
          Text(
            label,
            style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

/// Equal-width soft action button for the sheet's action row.
class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = destructive ? scheme.expense : scheme.onSurface;
    final shape = RoundedSuperellipseBorder(
      borderRadius: BorderRadius.circular(16),
    );
    return Expanded(
      child: Material(
        color: destructive
            ? scheme.expense.withValues(alpha: 0.10)
            : scheme.surfaceContainer,
        shape: shape,
        child: InkWell(
          customBorder: shape,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: Gaps.md),
            child: Column(
              children: [
                Icon(icon, size: 19, color: color),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
