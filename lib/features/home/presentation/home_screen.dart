import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:ledgr/app/theme/app_theme.dart';
import 'package:ledgr/core/db/database.dart';
import 'package:ledgr/core/money/money.dart';
import 'package:ledgr/core/money/money_formatter.dart';
import 'package:ledgr/core/providers/repository_providers.dart';
import 'package:ledgr/core/settings/settings_provider.dart';
import 'package:ledgr/core/widgets/amount_text.dart';
import 'package:ledgr/core/widgets/animated_amount.dart';
import 'package:ledgr/core/widgets/icon_badge.dart';
import 'package:ledgr/core/widgets/ledgr_header.dart';
import 'package:ledgr/core/widgets/menu_sheet.dart';
import 'package:ledgr/core/widgets/pressable.dart';
import 'package:ledgr/core/widgets/section_header.dart';
import 'package:ledgr/core/widgets/soft_icon_button.dart';
import 'package:ledgr/features/accounts/presentation/account_form_sheet.dart';
import 'package:ledgr/features/accounts/presentation/widgets/account_card.dart';
import 'package:ledgr/features/budgets/data/budget_repository.dart';
import 'package:ledgr/features/transactions/presentation/transaction_detail_sheet.dart';
import 'package:ledgr/features/transactions/presentation/tx_actions.dart';
import 'package:ledgr/features/transactions/presentation/widgets/transaction_tile.dart';
import 'package:ledgr/l10n/generated/app_localizations.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// The dashboard: hero net-worth panel, accounts carousel, spending snapshot,
/// and recent activity. Everything reads live from Drift streams.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppL10n.of(context);
    final formatter = ref.watch(moneyFormatterProvider);
    final currency = ref.watch(appSettingsProvider).homeCurrency;
    final hidden = ref.watch(
      appSettingsProvider.select((s) => s.amountsHidden),
    );
    final recent =
        ref.watch(periodTransactionsProvider).valueOrNull ?? const [];
    final categories = ref.watch(categoryMapProvider);
    final accountMap = ref.watch(accountMapProvider);

    return Scaffold(
      // SafeArea keeps scrolled content from sliding under the status-bar
      // clock (Saad hit this on device).
      body: SafeArea(
        bottom: false,
        child: ListView(
          children:
              [
                  LedgrHeader(
                    title: l10n.appName,
                    showLogo: true,
                    actions: [
                      SoftIconButton(
                        icon: hidden ? LucideIcons.eyeOff : LucideIcons.eye,
                        tooltip: hidden ? 'Show amounts' : 'Hide amounts',
                        onPressed: () => ref
                            .read(settingsControllerProvider.notifier)
                            .toggleAmountsHidden(),
                      ),
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
                              icon: LucideIcons.handCoins,
                              label: 'Debts',
                              subtitle: 'Money lent and borrowed',
                              onTap: () => context.push('/debts'),
                            ),
                            MenuSheetItem(
                              icon: LucideIcons.repeat,
                              label: 'Recurring',
                              subtitle: 'Scheduled transactions',
                              onTap: () => context.push('/recurring'),
                            ),
                            MenuSheetItem(
                              icon: LucideIcons.calendarClock,
                              label: 'Upcoming',
                              subtitle: "What's due next",
                              onTap: () => context.push('/upcoming'),
                            ),
                            MenuSheetItem(
                              icon: LucideIcons.settings,
                              label: 'Settings',
                              subtitle: 'Theme, security, backup',
                              onTap: () => context.push('/settings'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      Gaps.page,
                      Gaps.xs,
                      Gaps.page,
                      0,
                    ),
                    child: _HeroPanel(formatter: formatter, currency: currency),
                  ),
                  SectionHeader(
                    title: 'Accounts',
                    onAction: () => context.push('/accounts'),
                  ),
                  const _AccountsCarousel(),
                  _SpendingSnapshot(formatter: formatter, currency: currency),
                  _BudgetsSnapshot(formatter: formatter, currency: currency),
                  SectionHeader(
                    title: 'Recent activity',
                    onAction: () => context.push('/transactions'),
                  ),
                  if (recent.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(Gaps.xxl),
                      child: Center(
                        child: Text(
                          'No transactions yet',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: Gaps.sm),
                      child: Column(
                        children: [
                          for (final tx in recent.take(6))
                            TransactionTile(
                              transaction: tx,
                              formatter: formatter,
                              category: tx.categoryId == null
                                  ? null
                                  : categories[tx.categoryId],
                              accountName: accountMap[tx.accountId]?.name,
                              onEdit: () => editTransaction(context, tx.id),
                              onDelete: () => deleteTransactionWithUndo(
                                ref,
                                context,
                                tx.id,
                              ),
                              onTap: () =>
                                  TransactionDetailSheet.show(context, tx.id),
                            ),
                        ],
                      ),
                    ),
                  // No trailing spacer: this ListView has no explicit
                  // padding, so it auto-applies the ambient bottom inset the
                  // shell reports for the floating bar (extendBody).
                ]
                // Gentle staggered entrance for the dashboard sections.
                .animate(interval: 40.ms)
                .fadeIn(duration: 240.ms, curve: Curves.easeOut)
                .slideY(
                  begin: 0.05,
                  end: 0,
                  duration: 280.ms,
                  curve: Curves.easeOutCubic,
                ),
        ),
      ),
    );
  }
}

/// The confident top read: net worth, active period, and this period's
/// spent-vs-budget (or income/expense when no overall budget exists).
class _HeroPanel extends ConsumerWidget {
  const _HeroPanel({required this.formatter, required this.currency});

  final MoneyFormatter formatter;
  final String currency;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppL10n.of(context);
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final netWorth = ref.watch(netWorthProvider).valueOrNull ?? 0;
    final period = ref.watch(selectedPeriodProvider);
    final totals = ref.watch(monthTotalsProvider).valueOrNull;
    final budgets = ref.watch(budgetProgressProvider).valueOrNull ?? const [];
    final overallMatches = budgets.where((b) => b.isOverall);
    final overall = overallMatches.isEmpty ? null : overallMatches.first;

    final day = DateFormat('d MMM');
    final periodLabel =
        '${day.format(period.start)} – '
        '${day.format(period.end.subtract(const Duration(days: 1)))}';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: ShapeDecoration(
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(28),
        ),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: scheme.heroGradient,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.netWorthLabel.toUpperCase(),
                style: text.labelSmall?.copyWith(
                  color: scheme.onHeroMuted,
                  letterSpacing: 1.4,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: ShapeDecoration(
                  color: Colors.white.withValues(alpha: 0.10),
                  shape: RoundedSuperellipseBorder(
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                child: Text(
                  periodLabel,
                  style: text.labelSmall?.copyWith(color: scheme.onHeroMuted),
                ),
              ),
            ],
          ),
          const SizedBox(height: Gaps.sm),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: AnimatedAmount(
              Money(minor: netWorth, currency: currency),
              formatter: formatter,
              style: text.displaySmall?.copyWith(color: scheme.onHero),
            ),
          ),
          const SizedBox(height: Gaps.xl),
          if (overall != null)
            _HeroBudgetRead(
              spentMinor: overall.spentMinor,
              limitMinor: overall.limitMinor,
              currency: currency,
              formatter: formatter,
            )
          else
            Row(
              children: [
                Expanded(
                  child: _HeroStat(
                    label: 'Spent',
                    icon: LucideIcons.arrowDownLeft,
                    iconColor: const Color(0xFFFF9E8F),
                    money: Money(
                      minor: totals?.expenseMinor ?? 0,
                      currency: currency,
                    ),
                    formatter: formatter,
                  ),
                ),
                const SizedBox(width: Gaps.lg),
                Expanded(
                  child: _HeroStat(
                    label: 'Received',
                    icon: LucideIcons.arrowUpRight,
                    iconColor: const Color(0xFF7DE8AE),
                    money: Money(
                      minor: totals?.incomeMinor ?? 0,
                      currency: currency,
                    ),
                    formatter: formatter,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({
    required this.label,
    required this.icon,
    required this.iconColor,
    required this.money,
    required this.formatter,
  });

  final String label;
  final IconData icon;
  final Color iconColor;
  final Money money;
  final MoneyFormatter formatter;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Row(
      children: [
        IconBadge(
          icon: icon,
          color: iconColor,
          size: 30,
          iconSize: 16,
          background: Colors.white.withValues(alpha: 0.10),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: text.labelSmall?.copyWith(color: scheme.onHeroMuted),
              ),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: AmountText(
                  money,
                  formatter: formatter,
                  style: text.titleMedium?.copyWith(color: scheme.onHero),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// "Spent X of Y" with a progress track, shown when an overall budget exists.
class _HeroBudgetRead extends StatelessWidget {
  const _HeroBudgetRead({
    required this.spentMinor,
    required this.limitMinor,
    required this.currency,
    required this.formatter,
  });

  final int spentMinor;
  final int limitMinor;
  final String currency;
  final MoneyFormatter formatter;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final fraction = limitMinor <= 0
        ? 0.0
        : (spentMinor / limitMinor).clamp(0.0, 1.0);
    final over = spentMinor > limitMinor;
    final limitLabel = formatter.format(
      Money(minor: limitMinor, currency: currency),
    );
    final fill = over
        ? const Color(0xFFFF9E8F)
        : fraction >= 0.8
        ? const Color(0xFFFFC46B)
        : const Color(0xFF7DE8AE);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Flexible + ellipsis: big system fonts with real amounts would
            // otherwise overflow the hero card.
            Flexible(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: 'Spent ',
                      style: text.labelMedium?.copyWith(
                        color: scheme.onHeroMuted,
                      ),
                    ),
                    TextSpan(
                      text: formatter.format(
                        Money(minor: spentMinor, currency: currency),
                      ),
                      style: text.labelLarge?.copyWith(
                        color: scheme.onHero,
                        fontWeight: FontWeight.w800,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    TextSpan(
                      text: ' of $limitLabel',
                      style: text.labelMedium?.copyWith(
                        color: scheme.onHeroMuted,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: Gaps.sm),
            const Spacer(),
            Text(
              '${(fraction * 100).round()}%',
              style: text.labelMedium?.copyWith(color: scheme.onHeroMuted),
            ),
          ],
        ),
        const SizedBox(height: Gaps.sm),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: fraction),
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) => LinearProgressIndicator(
              value: value,
              minHeight: 8,
              backgroundColor: Colors.white.withValues(alpha: 0.12),
              color: fill,
            ),
          ),
        ),
      ],
    );
  }
}

class _AccountsCarousel extends ConsumerWidget {
  const _AccountsCarousel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountsAsync = ref.watch(activeAccountsProvider);
    final formatter = ref.watch(moneyFormatterProvider);
    return SizedBox(
      height: 168,
      child: accountsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (accounts) => ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: Gaps.lg),
          children: [
            for (final e in accounts)
              Padding(
                padding: const EdgeInsets.only(right: Gaps.md),
                child: Pressable(
                  child: AccountCard(
                    account: e.account,
                    balanceMinor: e.balanceMinor,
                    formatter: formatter,
                    onTap: () => context.push('/accounts/${e.account.id}'),
                  ),
                ),
              ),
            _AddAccountCard(onTap: () => AccountFormSheet.show(context)),
          ],
        ),
      ),
    );
  }
}

/// Top spending categories this period as a stacked bar + legend rows.
/// Tapping through lands on full reports.
class _SpendingSnapshot extends ConsumerWidget {
  const _SpendingSnapshot({required this.formatter, required this.currency});

  final MoneyFormatter formatter;
  final String currency;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spend = ref.watch(spendByCategoryProvider).valueOrNull ?? const [];
    final categories = ref.watch(categoryMapProvider);
    if (spend.isEmpty) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final total = spend.fold(0, (sum, s) => sum + s.totalMinor);
    if (total <= 0) return const SizedBox.shrink();
    final top = spend.take(4).toList();
    final restMinor = total - top.fold(0, (sum, s) => sum + s.totalMinor);

    Color colorFor(int categoryId) {
      final c = categories[categoryId];
      return c == null ? scheme.onSurfaceVariant : Color(c.color);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Spending',
          onAction: () => context.push('/reports'),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Gaps.page),
          child: Pressable(
            child: Card(
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => context.push('/reports'),
                child: Padding(
                  padding: const EdgeInsets.all(Gaps.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: Row(
                          children: [
                            for (final s in top)
                              Expanded(
                                flex: (s.totalMinor * 1000 ~/ total) + 1,
                                child: Container(
                                  height: 10,
                                  color: colorFor(s.categoryId),
                                ),
                              ),
                            if (restMinor > 0)
                              Expanded(
                                flex: (restMinor * 1000 ~/ total) + 1,
                                child: Container(
                                  height: 10,
                                  color: scheme.surfaceContainerHighest,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: Gaps.md),
                      for (final s in top.take(3))
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: colorFor(s.categoryId),
                                ),
                              ),
                              const SizedBox(width: Gaps.sm),
                              Expanded(
                                child: Text(
                                  categories[s.categoryId]?.name ??
                                      'Uncategorized',
                                  style: text.bodyMedium,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              AmountText(
                                Money(minor: s.totalMinor, currency: currency),
                                formatter: formatter,
                                style: text.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Per-budget progress rows (skips the overall budget — that lives in the
/// hero panel). Capped at three; the header links to the full list.
class _BudgetsSnapshot extends ConsumerWidget {
  const _BudgetsSnapshot({required this.formatter, required this.currency});

  final MoneyFormatter formatter;
  final String currency;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(budgetProgressProvider).valueOrNull ?? const [];
    final categories = ref.watch(categoryMapProvider);
    final scoped = progress.where((p) => !p.isOverall).toList()
      ..sort((a, b) => b.fraction.compareTo(a.fraction));
    if (scoped.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Budgets',
          onAction: () => context.push('/budgets'),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Gaps.page),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                Gaps.lg,
                Gaps.sm,
                Gaps.lg,
                Gaps.md,
              ),
              child: Column(
                children: [
                  for (final p in scoped.take(3))
                    _BudgetRow(
                      progress: p,
                      name: p.isOverall
                          ? 'Overall'
                          : _categoryPath(
                              categories,
                              categories[p.budget.categoryId],
                            ),
                      formatter: formatter,
                      currency: currency,
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// One budget's name, amount-left, and progress track.
class _BudgetRow extends StatelessWidget {
  const _BudgetRow({
    required this.progress,
    required this.name,
    required this.formatter,
    required this.currency,
  });

  final BudgetProgress progress;
  final String name;
  final MoneyFormatter formatter;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final over = progress.remainingMinor < 0;
    final amountLabel = formatter.format(
      Money(minor: progress.remainingMinor.abs(), currency: currency),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Gaps.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Long category names truncate rather than overflow the row.
              Expanded(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: Gaps.sm),
              Text(
                over ? '$amountLabel over' : '$amountLabel left',
                style: text.bodySmall?.copyWith(
                  color: over ? scheme.expense : scheme.onSurfaceVariant,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: progress.fraction,
              minHeight: 7,
              backgroundColor: scheme.surfaceContainerHighest,
              color: progress.fraction >= 1.0
                  ? scheme.expense
                  : progress.fraction >= 0.8
                  ? scheme.warning
                  : scheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _AddAccountCard extends StatelessWidget {
  const _AddAccountCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Pressable(
      child: Card(
        clipBehavior: Clip.antiAlias,
        color: Colors.transparent,
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: scheme.outlineVariant, width: 1.4),
        ),
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: 120,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(LucideIcons.plus, color: scheme.primary),
                const SizedBox(height: Gaps.sm),
                Text(
                  'Add account',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
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

/// "Parent > Child" for a subcategory, plain name otherwise.
String _categoryPath(Map<int, Category> categories, Category? c) => c == null
    ? 'Category'
    : c.parentId == null
    ? c.name
    : "${categories[c.parentId]?.name ?? '?'} > ${c.name}";
