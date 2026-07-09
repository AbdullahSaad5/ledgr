import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:ledgr/core/money/money.dart';
import 'package:ledgr/core/money/money_formatter.dart';
import 'package:ledgr/core/providers/repository_providers.dart';
import 'package:ledgr/core/settings/settings_provider.dart';
import 'package:ledgr/core/widgets/amount_text.dart';
import 'package:ledgr/core/widgets/app_icons.dart';
import 'package:ledgr/core/widgets/empty_state.dart';
import 'package:ledgr/features/budgets/data/budget_repository.dart';
import 'package:ledgr/features/budgets/presentation/budget_form_sheet.dart';

class BudgetsScreen extends ConsumerWidget {
  const BudgetsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(selectedPeriodProvider);
    final resolver = ref.watch(periodResolverProvider);
    final progressAsync = ref.watch(budgetProgressProvider);
    final formatter = ref.watch(moneyFormatterProvider);
    final categories = ref.watch(categoryMapProvider);
    final currency = ref.watch(appSettingsProvider).homeCurrency;
    final label = DateFormat.yMMMM().format(
      DateTime(period.anchorYear, period.anchorMonth),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Budgets'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () =>
                    ref.read(selectedPeriodProvider.notifier).state = resolver
                        .previous(period),
              ),
              SizedBox(
                width: 160,
                child: Text(label, textAlign: TextAlign.center),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () =>
                    ref.read(selectedPeriodProvider.notifier).state = resolver
                        .next(period),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => BudgetFormSheet.show(context),
        icon: const Icon(Icons.add),
        label: const Text('Budget'),
      ),
      body: progressAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (items) {
          if (items.isEmpty) {
            return EmptyState(
              icon: Icons.pie_chart_outline,
              title: 'No budgets yet',
              message: 'Set a monthly limit to track your spending.',
              action: FilledButton.icon(
                onPressed: () => BudgetFormSheet.show(context),
                icon: const Icon(Icons.add),
                label: const Text('Add budget'),
              ),
            );
          }
          items.sort((a, b) => b.fraction.compareTo(a.fraction));
          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              for (final p in items)
                _BudgetTile(
                  progress: p,
                  formatter: formatter,
                  currency: currency,
                  categoryName: p.isOverall
                      ? 'Overall'
                      : categories[p.budget.categoryId]?.name ?? 'Category',
                  icon: p.isOverall
                      ? Icons.account_balance_wallet
                      : AppIcons.resolve(
                          categories[p.budget.categoryId]?.icon ?? 'category',
                        ),
                  onEdit: () => BudgetFormSheet.show(context, budget: p.budget),
                  onDelete: () =>
                      ref.read(budgetRepositoryProvider).delete(p.budget.id),
                ),
              const SizedBox(height: 80),
            ],
          );
        },
      ),
    );
  }
}

class _BudgetTile extends StatelessWidget {
  const _BudgetTile({
    required this.progress,
    required this.formatter,
    required this.currency,
    required this.categoryName,
    required this.icon,
    required this.onEdit,
    required this.onDelete,
  });

  final BudgetProgress progress;
  final MoneyFormatter formatter;
  final String currency;
  final String categoryName;
  final IconData icon;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fraction = progress.fraction;
    final barColor = fraction >= 1.0
        ? scheme.error
        : fraction >= 0.8
        ? Colors.orange
        : scheme.primary;
    final limit = Money(minor: progress.limitMinor, currency: currency);
    final limitLabel = 'of ${formatter.format(limit)}';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: scheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    categoryName,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (v) => v == 'edit' ? onEdit() : onDelete(),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('Edit')),
                    PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: fraction,
                minHeight: 10,
                backgroundColor: scheme.surfaceContainerHighest,
                color: barColor,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                AmountText(
                  Money(minor: progress.spentMinor, currency: currency),
                  formatter: formatter,
                ),
                Text(
                  limitLabel,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
