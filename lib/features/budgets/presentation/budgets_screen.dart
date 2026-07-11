import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ledgr/app/theme/app_theme.dart';
import 'package:ledgr/app/widgets/ledgr_nav_bar.dart';
import 'package:ledgr/core/db/database.dart';
import 'package:ledgr/core/money/money.dart';
import 'package:ledgr/core/money/money_formatter.dart';
import 'package:ledgr/core/providers/repository_providers.dart';
import 'package:ledgr/core/settings/settings_provider.dart';
import 'package:ledgr/core/widgets/amount_text.dart';
import 'package:ledgr/core/widgets/app_icons.dart';
import 'package:ledgr/core/widgets/empty_state.dart';
import 'package:ledgr/core/widgets/icon_badge.dart';
import 'package:ledgr/core/widgets/ledgr_header.dart';
import 'package:ledgr/core/widgets/menu_sheet.dart';
import 'package:ledgr/core/widgets/period_switcher.dart';
import 'package:ledgr/core/widgets/pressable.dart';
import 'package:ledgr/features/budgets/data/budget_repository.dart';
import 'package:ledgr/features/budgets/presentation/budget_form_sheet.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

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

    // The empty state carries its own Add-budget CTA, so the FAB only shows
    // once budgets exist. Lifted by the ambient bottom padding (floating bar
    // + system inset under extendBody): the Scaffold does not raise the FAB
    // itself — verified on-device, it rests behind the pill otherwise.
    final hasBudgets = (progressAsync.valueOrNull ?? const []).isNotEmpty;

    return Scaffold(
      floatingActionButton: hasBudgets
          ? Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.paddingOf(context).bottom,
              ),
              child: FloatingActionButton.extended(
                onPressed: () => BudgetFormSheet.show(context),
                icon: const Icon(LucideIcons.plus),
                label: const Text('Budget'),
              ),
            )
          : null,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const LedgrHeader(title: 'Budgets'),
            PeriodSwitcher(
              period: period,
              onPrev: () => ref.read(selectedPeriodProvider.notifier).state =
                  resolver.previous(period),
              onNext: () => ref.read(selectedPeriodProvider.notifier).state =
                  resolver.next(period),
            ),
            Expanded(
              child: progressAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('$e')),
                data: (items) {
                  if (items.isEmpty) {
                    return EmptyState(
                      icon: LucideIcons.pieChart,
                      title: 'No budgets yet',
                      message: 'Set a monthly limit to track your spending.',
                      action: FilledButton.icon(
                        onPressed: () => BudgetFormSheet.show(context),
                        icon: const Icon(LucideIcons.plus),
                        label: const Text('Add budget'),
                      ),
                    );
                  }
                  items.sort((a, b) => b.fraction.compareTo(a.fraction));
                  return ListView(
                    // Extra 72 clears the FAB stacked above the nav pill.
                    padding: EdgeInsets.fromLTRB(
                      Gaps.page,
                      Gaps.xs,
                      Gaps.page,
                      LedgrNavBar.clearanceOf(context) + 72,
                    ),
                    children: [
                      for (final p in items) ...[
                        _BudgetTile(
                          progress: p,
                          formatter: formatter,
                          currency: currency,
                          categoryName: p.isOverall
                              ? 'Overall'
                              : _categoryPath(
                                  categories,
                                  categories[p.budget.categoryId],
                                ),
                          icon: p.isOverall
                              ? LucideIcons.wallet
                              : AppIcons.resolve(
                                  categories[p.budget.categoryId]?.icon ??
                                      'category',
                                ),
                          accent: p.isOverall
                              ? Theme.of(context).colorScheme.primary
                              : Color(
                                  categories[p.budget.categoryId]?.color ??
                                      0xFF607D8B,
                                ),
                          onEdit: () =>
                              BudgetFormSheet.show(context, budget: p.budget),
                          onDelete: () => ref
                              .read(budgetRepositoryProvider)
                              .delete(p.budget.id),
                        ),
                        const SizedBox(height: Gaps.md),
                      ],
                    ],
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

class _BudgetTile extends StatelessWidget {
  const _BudgetTile({
    required this.progress,
    required this.formatter,
    required this.currency,
    required this.categoryName,
    required this.icon,
    required this.accent,
    required this.onEdit,
    required this.onDelete,
  });

  final BudgetProgress progress;
  final MoneyFormatter formatter;
  final String currency;
  final String categoryName;
  final IconData icon;
  final Color accent;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final fraction = progress.fraction;
    final over = progress.remainingMinor < 0;
    final barColor = fraction >= 1.0
        ? scheme.expense
        : fraction >= 0.8
        ? scheme.warning
        : scheme.primary;
    final remaining = Money(
      minor: progress.remainingMinor.abs(),
      currency: currency,
    );
    final limitLabel = formatter.format(
      Money(minor: progress.limitMinor, currency: currency),
    );

    return Pressable(
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onEdit,
          child: Padding(
            padding: const EdgeInsets.all(Gaps.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconBadge(
                      icon: icon,
                      color: accent,
                      size: 38,
                      iconSize: 18,
                    ),
                    const SizedBox(width: Gaps.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(categoryName, style: text.titleSmall),
                          Text(
                            over
                                ? '${formatter.format(remaining)} over'
                                : '${formatter.format(remaining)} left',
                            style: text.labelSmall?.copyWith(
                              color: over
                                  ? scheme.expense
                                  : scheme.onSurfaceVariant,
                            ),
                          ),
                          if (progress.carryMinor != 0)
                            Builder(
                              builder: (context) {
                                final carry = formatter.format(
                                  Money(
                                    minor: progress.carryMinor.abs(),
                                    currency: currency,
                                  ),
                                );
                                final up = progress.carryMinor > 0;
                                return Text(
                                  up
                                      ? '$carry rolled over'
                                      : '$carry overspent before',
                                  style: text.labelSmall?.copyWith(
                                    color: up ? scheme.income : scheme.expense,
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                    Text(
                      '${(fraction * 100).round()}%',
                      style: text.titleSmall?.copyWith(color: barColor),
                    ),
                    IconButton(
                      icon: const Icon(LucideIcons.moreVertical, size: 18),
                      visualDensity: VisualDensity.compact,
                      onPressed: () => MenuSheet.show(
                        context,
                        title: categoryName,
                        items: [
                          MenuSheetItem(
                            icon: LucideIcons.pencil,
                            label: 'Edit',
                            onTap: onEdit,
                          ),
                          MenuSheetItem(
                            icon: LucideIcons.trash2,
                            label: 'Delete',
                            onTap: onDelete,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Gaps.md),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: fraction),
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, _) => LinearProgressIndicator(
                      value: value,
                      minHeight: 9,
                      backgroundColor: scheme.surfaceContainerHighest,
                      color: barColor,
                    ),
                  ),
                ),
                const SizedBox(height: Gaps.sm),
                Row(
                  children: [
                    // Flexible: seven-digit amounts at large font scales
                    // squeeze instead of overflowing the tile footer.
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: AmountText(
                          Money(
                            minor: progress.spentMinor,
                            currency: currency,
                          ),
                          formatter: formatter,
                          style: text.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const Spacer(),
                    const SizedBox(width: 8),
                    Text(
                      'of $limitLabel',
                      style: text.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "Parent > Child" for a subcategory, plain name otherwise.
String _categoryPath(Map<int, Category> categories, Category? c) => c == null
    ? 'Category'
    : c.parentId == null
    ? c.name
    : "${categories[c.parentId]?.name ?? '?'} > ${c.name}";
