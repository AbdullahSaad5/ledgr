import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:ledgr/app/theme/app_theme.dart';
import 'package:ledgr/core/money/money.dart';
import 'package:ledgr/core/money/money_formatter.dart';
import 'package:ledgr/core/providers/repository_providers.dart';
import 'package:ledgr/core/settings/settings_provider.dart';
import 'package:ledgr/core/widgets/amount_text.dart';
import 'package:ledgr/core/widgets/animated_amount.dart';
import 'package:ledgr/core/widgets/pressable.dart';
import 'package:ledgr/features/accounts/presentation/account_form_sheet.dart';
import 'package:ledgr/features/accounts/presentation/widgets/account_card.dart';
import 'package:ledgr/features/budgets/data/budget_repository.dart';
import 'package:ledgr/features/transactions/presentation/transaction_detail_sheet.dart';
import 'package:ledgr/features/transactions/presentation/widgets/transaction_tile.dart';
import 'package:ledgr/l10n/generated/app_localizations.dart';

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
      appBar: AppBar(
        title: Text(l10n.appName),
        actions: [
          IconButton(
            tooltip: hidden ? 'Show amounts' : 'Hide amounts',
            icon: Icon(hidden ? Icons.visibility_off : Icons.visibility),
            onPressed: () => ref
                .read(settingsControllerProvider.notifier)
                .toggleAmountsHidden(),
          ),
          IconButton(
            tooltip: 'Search',
            icon: const Icon(Icons.search),
            onPressed: () => context.push('/search'),
          ),
          PopupMenuButton<String>(
            onSelected: (v) => context.push('/$v'),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'debts', child: Text('Debts')),
              PopupMenuItem(value: 'recurring', child: Text('Recurring')),
              PopupMenuItem(value: 'upcoming', child: Text('Upcoming')),
              PopupMenuItem(value: 'settings', child: Text('Settings')),
            ],
          ),
        ],
      ),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Gaps.page,
              Gaps.xs,
              Gaps.page,
              0,
            ),
            child: _HeroPanel(formatter: formatter, currency: currency),
          ),
          const _SectionHeader(title: 'Accounts', route: '/accounts'),
          const _AccountsCarousel(),
          _SpendingSnapshot(formatter: formatter, currency: currency),
          _BudgetsSnapshot(formatter: formatter, currency: currency),
          const _SectionHeader(
            title: 'Recent activity',
            route: '/transactions',
          ),
          if (recent.isEmpty)
            Padding(
              padding: const EdgeInsets.all(Gaps.xxl),
              child: Center(
                child: Text(
                  'No transactions yet',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                      onTap: () => TransactionDetailSheet.show(context, tx.id),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 96),
        ],
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
          AnimatedAmount(
            Money(minor: netWorth, currency: currency),
            formatter: formatter,
            style: text.displaySmall?.copyWith(color: scheme.onHero),
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
                _HeroStat(
                  label: 'Spent',
                  icon: Icons.south,
                  iconColor: const Color(0xFFFF9E8F),
                  money: Money(
                    minor: totals?.expenseMinor ?? 0,
                    currency: currency,
                  ),
                  formatter: formatter,
                ),
                const SizedBox(width: Gaps.xxl),
                _HeroStat(
                  label: 'Received',
                  icon: Icons.north,
                  iconColor: const Color(0xFF7DE8AE),
                  money: Money(
                    minor: totals?.incomeMinor ?? 0,
                    currency: currency,
                  ),
                  formatter: formatter,
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
        Container(
          width: 30,
          height: 30,
          decoration: ShapeDecoration(
            color: Colors.white.withValues(alpha: 0.10),
            shape: RoundedSuperellipseBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: Icon(icon, size: 16, color: iconColor),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: text.labelSmall?.copyWith(color: scheme.onHeroMuted),
            ),
            AmountText(
              money,
              formatter: formatter,
              style: text.titleMedium?.copyWith(color: scheme.onHero),
            ),
          ],
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
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text.rich(
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
            ),
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

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.route});

  final String title;
  final String? route;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Gaps.page, Gaps.xl, Gaps.md, Gaps.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          if (route != null)
            TextButton(
              onPressed: () => context.push(route!),
              child: const Text('See all'),
            ),
        ],
      ),
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
        const _SectionHeader(title: 'Spending', route: '/reports'),
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
                                  categories[s.categoryId]?.name ?? 'Other',
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
        const _SectionHeader(title: 'Budgets', route: '/budgets'),
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
                      name: categories[p.budget.categoryId]?.name ?? 'Budget',
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
    final leftLabel = formatter.format(
      Money(
        minor: progress.remainingMinor.clamp(0, progress.limitMinor),
        currency: currency,
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Gaps.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                name,
                style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              Text(
                '$leftLabel left',
                style: text.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
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
                Icon(Icons.add, color: scheme.primary),
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
