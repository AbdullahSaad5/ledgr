import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:ledgr/app/theme/app_theme.dart';
import 'package:ledgr/core/db/database.dart';
import 'package:ledgr/core/db/enums.dart';
import 'package:ledgr/core/money/money.dart';
import 'package:ledgr/core/money/money_formatter.dart';
import 'package:ledgr/core/providers/repository_providers.dart';
import 'package:ledgr/core/settings/settings_provider.dart';
import 'package:ledgr/core/time/period_resolver.dart';
import 'package:ledgr/core/widgets/amount_text.dart';
import 'package:ledgr/core/widgets/app_icons.dart';
import 'package:ledgr/core/widgets/empty_state.dart';
import 'package:ledgr/core/widgets/icon_badge.dart';
import 'package:ledgr/core/widgets/insight_tile.dart';
import 'package:ledgr/core/widgets/ledgr_header.dart';
import 'package:ledgr/core/widgets/menu_sheet.dart';
import 'package:ledgr/core/widgets/period_switcher.dart';
import 'package:ledgr/core/widgets/section_header.dart';
import 'package:ledgr/core/widgets/soft_icon_button.dart';
import 'package:ledgr/core/widgets/stat_card.dart';
import 'package:ledgr/features/reports/domain/report_models.dart';
import 'package:ledgr/features/reports/presentation/charts.dart';
import 'package:ledgr/features/reports/presentation/report_export.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(selectedPeriodProvider);
    final resolver = ref.watch(periodResolverProvider);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              LedgrHeader(
                title: 'Reports',
                actions: [
                  SoftIconButton(
                    icon: LucideIcons.share,
                    tooltip: 'Export CSV',
                    onPressed: () => MenuSheet.show(
                      context,
                      title: 'Export CSV',
                      items: [
                        MenuSheetItem(
                          icon: LucideIcons.calendar,
                          label: 'This period',
                          onTap: () => exportPeriodCsv(ref),
                        ),
                        MenuSheetItem(
                          icon: LucideIcons.calendarRange,
                          label: 'All transactions',
                          onTap: () => exportPeriodCsv(ref, all: true),
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
              const TabBar(
                tabs: [
                  Tab(text: 'Overview'),
                  Tab(text: 'Trends'),
                  Tab(text: 'Net worth'),
                ],
              ),
              const Expanded(
                child: TabBarView(
                  children: [_OverviewTab(), _TrendsTab(), _NetWorthTab()],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OverviewTab extends ConsumerWidget {
  const _OverviewTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totals = ref.watch(monthTotalsProvider);
    final spend = ref.watch(spendByCategoryProvider);
    final payees = ref.watch(topPayeesProvider);
    final categories = ref.watch(categoryMapProvider);
    final formatter = ref.watch(moneyFormatterProvider);
    final currency = ref.watch(appSettingsProvider).homeCurrency;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return ListView(
      padding: const EdgeInsets.only(top: Gaps.md, bottom: 120),
      children: [
        totals.when(
          loading: () => const SizedBox(
            height: 60,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Text('$e'),
          data: (t) => StatCard(
            formatter: formatter,
            items: [
              StatItem(
                label: 'Income',
                money: Money(minor: t.incomeMinor, currency: currency),
                tone: AmountTone.income,
              ),
              StatItem(
                label: 'Expense',
                money: Money(minor: t.expenseMinor, currency: currency),
                tone: AmountTone.expense,
              ),
              StatItem(
                label: 'Net',
                money: Money(minor: t.netMinor, currency: currency),
                tone: AmountTone.auto,
              ),
            ],
          ),
        ),
        const _DailyRhythm(),
        spend.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('$e'),
          data: (items) {
            if (items.isEmpty) {
              return const EmptyState(
                icon: LucideIcons.pieChart,
                title: 'No spending yet',
                message: 'Expenses this month appear here as a breakdown.',
              );
            }
            final total = items.fold(0, (s, e) => s + e.totalMinor);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionHeader(title: 'Spending by category'),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Gaps.page),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(Gaps.lg),
                      child: Column(
                        children: [
                          SizedBox(
                            height: 190,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                SfCircularChart(
                                  margin: EdgeInsets.zero,
                                  series: [
                                    DoughnutSeries<CategorySpend, String>(
                                      dataSource: items,
                                      xValueMapper: (e, _) =>
                                          categories[e.categoryId]?.name ??
                                          'Uncategorized',
                                      yValueMapper: (e, _) => e.totalMinor,
                                      pointColorMapper: (e, _) => Color(
                                        categories[e.categoryId]?.color ??
                                            0xFF9E9E9E,
                                      ),
                                      innerRadius: '78%',
                                      radius: '100%',
                                      cornerStyle: CornerStyle.bothCurve,
                                      // Card-colored stroke separates the
                                      // segments (Saad's reference look).
                                      strokeColor: scheme.surfaceContainerLow,
                                      strokeWidth: 4,
                                      animationDuration: 700,
                                    ),
                                  ],
                                ),
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'TOTAL SPENT',
                                      style: text.labelSmall?.copyWith(
                                        color: scheme.onSurfaceVariant,
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                    AmountText(
                                      Money(minor: total, currency: currency),
                                      formatter: formatter,
                                      style: text.titleMedium,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: Gaps.md),
                          for (final e in items)
                            _SpendRow(
                              spend: e,
                              total: total,
                              currency: currency,
                              formatter: formatter,
                              category: categories[e.categoryId],
                              // Only parents with subcategories drill down.
                              hasChildren: categories.values.any(
                                (c) => c.parentId == e.categoryId,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        payees.maybeWhen(
          data: (list) => list.isEmpty
              ? const SizedBox.shrink()
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionHeader(title: 'Top payees'),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Gaps.page,
                      ),
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: Gaps.lg,
                            vertical: Gaps.sm,
                          ),
                          child: Column(
                            children: [
                              for (final p in list)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 7,
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          p.payee,
                                          style: text.bodyMedium,
                                        ),
                                      ),
                                      AmountText(
                                        Money(
                                          minor: p.totalMinor,
                                          currency: currency,
                                        ),
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
                  ],
                ),
          orElse: () => const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class _TrendsTab extends ConsumerWidget {
  const _TrendsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trend = ref.watch(monthlyTrendProvider);
    final txs = ref.watch(periodTransactionsProvider).valueOrNull ?? const [];
    final spend = ref.watch(spendByCategoryProvider).valueOrNull ?? const [];
    final budgets = ref.watch(budgetProgressProvider).valueOrNull ?? const [];
    final categories = ref.watch(categoryMapProvider);
    final period = ref.watch(selectedPeriodProvider);
    final formatter = ref.watch(moneyFormatterProvider);
    final currency = ref.watch(appSettingsProvider).homeCurrency;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    // --- This period's insights, computed from live data. ---
    final now = DateTime.now();
    final periodEnded = now.isAfter(period.end);
    final elapsedDays = periodEnded
        ? period.end.difference(period.start).inDays
        : now.difference(period.start).inDays + 1;
    final totalDays = period.end.difference(period.start).inDays;
    final spentMinor = txs
        .where((t) => t.type == TxType.expense)
        .fold(0, (sum, t) => sum + t.amountMinor);
    final dailyAvg = elapsedDays <= 0 ? 0 : spentMinor ~/ elapsedDays;
    final projected = periodEnded ? spentMinor : dailyAvg * totalDays;

    Transaction? biggest;
    for (final t in txs) {
      if (t.type != TxType.expense) continue;
      if (biggest == null || t.amountMinor > biggest.amountMinor) biggest = t;
    }

    final overallMatches = budgets.where((b) => b.isOverall);
    final overall = overallMatches.isEmpty ? null : overallMatches.first;
    String? projectionCaption;
    Color? projectionAccent;
    if (overall != null && overall.limitMinor > 0 && !periodEnded) {
      final over = projected > overall.limitMinor;
      projectionCaption = over
          ? 'On pace to exceed your budget'
          : 'On pace to stay under budget';
      projectionAccent = over ? scheme.expense : scheme.income;
    }

    final topCategory = spend.isEmpty ? null : spend.first;
    final spendTotal = spend.fold(0, (sum, e) => sum + e.totalMinor);
    final topShare = topCategory == null || spendTotal == 0
        ? 0
        : (topCategory.totalMinor / spendTotal * 100).round();

    String money(int minor) =>
        formatter.format(Money(minor: minor, currency: currency));

    return trend.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (points) {
        final active = points
            .where((p) => p.incomeMinor != 0 || p.expenseMinor != 0)
            .toList();

        return ListView(
          padding: const EdgeInsets.fromLTRB(
            Gaps.page,
            Gaps.md,
            Gaps.page,
            120,
          ),
          children: [
            if (txs.isEmpty && active.isEmpty)
              const EmptyState(
                icon: LucideIcons.barChart3,
                title: 'No insights yet',
                message: 'Log a few expenses and this fills up.',
              )
            else ...[
              Row(
                children: [
                  Expanded(
                    child: InsightTile(
                      icon: LucideIcons.calendarDays,
                      label: 'Daily average',
                      value: money(dailyAvg),
                      caption:
                          'Over $elapsedDays day'
                          '${elapsedDays == 1 ? '' : 's'} so far',
                    ),
                  ),
                  const SizedBox(width: Gaps.md),
                  Expanded(
                    child: InsightTile(
                      icon: LucideIcons.trendingUp,
                      label: periodEnded ? 'Total spent' : 'Projected total',
                      value: money(projected),
                      caption:
                          projectionCaption ??
                          (periodEnded
                              ? 'This period is over'
                              : 'At your current pace'),
                      accent: projectionAccent,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Gaps.md),
              Row(
                children: [
                  Expanded(
                    child: InsightTile(
                      icon: LucideIcons.receipt,
                      label: 'Biggest expense',
                      value: biggest == null ? '—' : money(biggest.amountMinor),
                      caption: biggest == null
                          ? 'Nothing this period'
                          : (biggest.payee ??
                                categories[biggest.categoryId]?.name ??
                                'Uncategorized'),
                    ),
                  ),
                  const SizedBox(width: Gaps.md),
                  Expanded(
                    child: InsightTile(
                      icon: LucideIcons.shapes,
                      label: 'Top category',
                      value: topCategory == null
                          ? '—'
                          : categories[topCategory.categoryId]?.name ?? 'Other',
                      caption: topCategory == null || spendTotal == 0
                          ? 'Nothing categorized yet'
                          : '$topShare% of spending '
                                '(${money(topCategory.totalMinor)})',
                      accent: topCategory == null
                          ? null
                          : Color(
                              categories[topCategory.categoryId]?.color ??
                                  0xFF9E9E9E,
                            ),
                    ),
                  ),
                ],
              ),
            ],
            const _SpendingPace(),
            const _CategoryShift(),
            // The month-on-month chart earns its place only once there is
            // more than one month to compare.
            if (active.length >= 2) ...[
              const SizedBox(height: Gaps.sm),
              const SectionHeader(title: 'Month by month'),
              Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Gaps.sm,
                    Gaps.xl,
                    Gaps.lg,
                    Gaps.lg,
                  ),
                  child: _MonthBars(
                    points: active.length > 6
                        ? active.sublist(active.length - 6)
                        : active,
                    formatter: formatter,
                    currency: currency,
                  ),
                ),
              ),
            ] else if (txs.isNotEmpty) ...[
              const SizedBox(height: Gaps.md),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(Gaps.lg),
                  child: Row(
                    children: [
                      Icon(
                        LucideIcons.barChart3,
                        size: 18,
                        color: scheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: Gaps.md),
                      Expanded(
                        child: Text(
                          'Month-on-month trends appear after your second '
                          'month of data.',
                          style: text.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

/// Income vs expense bars over the months that actually have data —
/// every month labelled, tooltips on tap.
class _MonthBars extends StatelessWidget {
  const _MonthBars({
    required this.points,
    required this.formatter,
    required this.currency,
  });

  final List<MonthPoint> points;
  final MoneyFormatter formatter;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        SizedBox(
          height: 220,
          child: cartesian(
            context: context,
            currency: currency,
            tooltip: moneyTooltip(context, formatter, currency),
            series: [
              ColumnSeries<MonthPoint, String>(
                dataSource: points,
                xValueMapper: (p, _) =>
                    DateFormat.MMM().format(DateTime(p.year, p.month)),
                yValueMapper: (p, _) => p.incomeMinor,
                color: scheme.income,
                width: 0.7,
                spacing: 0.12,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(4),
                ),
                animationDuration: 600,
              ),
              ColumnSeries<MonthPoint, String>(
                dataSource: points,
                xValueMapper: (p, _) =>
                    DateFormat.MMM().format(DateTime(p.year, p.month)),
                yValueMapper: (p, _) => p.expenseMinor,
                color: scheme.expense,
                width: 0.7,
                spacing: 0.12,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(4),
                ),
                animationDuration: 600,
              ),
            ],
          ),
        ),
        const SizedBox(height: Gaps.md),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _legend(context, scheme.income, 'Income'),
            const SizedBox(width: Gaps.lg),
            _legend(context, scheme.expense, 'Expense'),
          ],
        ),
      ],
    );
  }

  Widget _legend(BuildContext context, Color color, String label) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 5),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}

class _NetWorthTab extends ConsumerWidget {
  const _NetWorthTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final series = ref.watch(netWorthSeriesProvider);
    final formatter = ref.watch(moneyFormatterProvider);
    final currency = ref.watch(appSettingsProvider).homeCurrency;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return series.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (points) {
        if (points.isEmpty) {
          return const EmptyState(
            icon: LucideIcons.trendingUp,
            title: 'No history yet',
            message: 'Net worth over time appears here.',
          );
        }
        final current = points.last.minor;
        final delta = current - points.first.minor;
        final up = delta >= 0;
        final deltaColor = up ? scheme.income : scheme.expense;
        final deltaMoney = formatter.format(
          Money(minor: delta.abs(), currency: currency),
        );

        return ListView(
          padding: const EdgeInsets.fromLTRB(
            Gaps.page,
            Gaps.md,
            Gaps.page,
            120,
          ),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(Gaps.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Net worth today',
                      style: text.labelMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: AmountText(
                        Money(minor: current, currency: currency),
                        formatter: formatter,
                        style: text.headlineSmall,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          up
                              ? LucideIcons.arrowUpRight
                              : LucideIcons.arrowDownLeft,
                          size: 14,
                          color: deltaColor,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            '$deltaMoney over ${points.length} months',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: text.labelSmall?.copyWith(
                              color: deltaColor,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: Gaps.xl),
                    SizedBox(
                      height: 200,
                      child: cartesian(
                        context: context,
                        tooltip: moneyTooltip(context, formatter, currency),
                        xAxis: CategoryAxis(
                          majorGridLines: const MajorGridLines(width: 0),
                          axisLine: const AxisLine(width: 0),
                          majorTickLines: const MajorTickLines(size: 0),
                          interval: (points.length / 4).ceilToDouble().clamp(
                            1,
                            12,
                          ),
                          labelStyle: text.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        yAxis: const NumericAxis(isVisible: false),
                        series: [
                          SplineAreaSeries<NetWorthPoint, String>(
                            dataSource: points,
                            xValueMapper: (p, _) =>
                                DateFormat.MMM().format(p.date),
                            yValueMapper: (p, _) => p.minor,
                            splineType: SplineType.monotonic,
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                scheme.primary.withValues(alpha: 0.25),
                                scheme.primary.withValues(alpha: 0),
                              ],
                            ),
                            borderColor: scheme.primary,
                            borderWidth: 3,
                            animationDuration: 700,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const _AccountComposition(),
          ],
        );
      },
    );
  }
}

/// Spending per day of the selected period — shows the rhythm of the month
/// (payday splurges, quiet weeks) at a glance.
class _DailyRhythm extends ConsumerWidget {
  const _DailyRhythm();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final txs = ref.watch(periodTransactionsProvider).valueOrNull ?? const [];
    final period = ref.watch(selectedPeriodProvider);
    final formatter = ref.watch(moneyFormatterProvider);
    final currency = ref.watch(appSettingsProvider).homeCurrency;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    final days = period.end.difference(period.start).inDays;
    final perDay = List<int>.filled(days, 0);
    for (final t in txs) {
      if (t.type != TxType.expense) continue;
      final i = t.date.difference(period.start).inDays;
      if (i >= 0 && i < days) perDay[i] += t.amountMinor;
    }
    if (perDay.every((v) => v == 0)) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Daily spending'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Gaps.page),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                Gaps.lg,
                Gaps.xl,
                Gaps.lg,
                Gaps.md,
              ),
              child: SizedBox(
                height: 180,
                // A line with real axes (Saad: bars with no scale were
                // unreadable): compact money labels on the y, "Day N" on
                // the x, quiet dashed gridlines.
                child: cartesian(
                  context: context,
                  currency: currency,
                  tooltip: moneyTooltip(context, formatter, currency),
                  xAxis: NumericAxis(
                    majorGridLines: const MajorGridLines(width: 0),
                    axisLine: const AxisLine(width: 0),
                    majorTickLines: const MajorTickLines(size: 0),
                    minimum: 1,
                    maximum: days.toDouble(),
                    interval: ((days - 1) / 3).ceilToDouble(),
                    axisLabelFormatter: (args) => ChartAxisLabel(
                      'Day ${args.value.toInt()}',
                      text.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ),
                  series: [
                    LineSeries<MoneyPoint, num>(
                      dataSource: [
                        for (var i = 0; i < days; i++)
                          MoneyPoint('Day ${i + 1}', perDay[i]),
                      ],
                      xValueMapper: (p, i) => i + 1,
                      yValueMapper: (p, _) => p.minor,
                      color: scheme.primary,
                      width: 3,
                      animationDuration: 600,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Cumulative spend this period vs last — are you burning faster or slower
/// than last month?
class _SpendingPace extends ConsumerWidget {
  const _SpendingPace();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final txs = ref.watch(periodTransactionsProvider).valueOrNull ?? const [];
    final prevTxs =
        ref.watch(previousPeriodTransactionsProvider).valueOrNull ?? const [];
    final period = ref.watch(selectedPeriodProvider);
    final prevPeriod = ref.watch(previousPeriodProvider);
    final formatter = ref.watch(moneyFormatterProvider);
    final currency = ref.watch(appSettingsProvider).homeCurrency;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    List<int> cumulative(List<Transaction> list, Period p, int days) {
      final perDay = List<int>.filled(days, 0);
      for (final t in list) {
        if (t.type != TxType.expense) continue;
        final i = t.date.difference(p.start).inDays;
        if (i >= 0 && i < days) perDay[i] += t.amountMinor;
      }
      var running = 0;
      return [for (final v in perDay) running += v];
    }

    final days = period.end.difference(period.start).inDays;
    final prevDays = prevPeriod.end.difference(prevPeriod.start).inDays;
    final now = DateTime.now();
    final elapsed = now.isAfter(period.end)
        ? days
        : (now.difference(period.start).inDays + 1).clamp(1, days);

    final thisCum = cumulative(txs, period, days).sublist(0, elapsed);
    final prevCum = cumulative(prevTxs, prevPeriod, prevDays);
    if (prevCum.isEmpty || prevCum.last == 0 || thisCum.isEmpty) {
      return const SizedBox.shrink();
    }

    final samePoint = elapsed.clamp(1, prevDays) - 1;
    final ahead = thisCum.last > prevCum[samePoint];
    final nowLabel = formatter.format(
      Money(minor: thisCum.last, currency: currency),
    );
    final thenLabel = formatter.format(
      Money(minor: prevCum[samePoint], currency: currency),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: Gaps.sm),
        const SectionHeader(title: 'Spending pace'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(Gaps.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ahead
                      ? 'Spending faster than last month'
                      : 'Spending slower than last month',
                  style: text.titleSmall?.copyWith(
                    color: ahead ? scheme.expense : scheme.income,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Day $elapsed: $nowLabel now vs $thenLabel then',
                  style: text.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: Gaps.lg),
                SizedBox(
                  height: 160,
                  child: cartesian(
                    context: context,
                    xAxis: const NumericAxis(isVisible: false),
                    yAxis: const NumericAxis(isVisible: false),
                    series: [
                      LineSeries<MoneyPoint, num>(
                        dataSource: [
                          for (var i = 0; i < prevCum.length; i++)
                            MoneyPoint('${i + 1}', prevCum[i]),
                        ],
                        xValueMapper: (p, i) => i,
                        yValueMapper: (p, _) => p.minor,
                        color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
                        width: 2,
                        dashArray: const [5, 5],
                        animationDuration: 600,
                      ),
                      LineSeries<MoneyPoint, num>(
                        dataSource: [
                          for (var i = 0; i < thisCum.length; i++)
                            MoneyPoint('${i + 1}', thisCum[i]),
                        ],
                        xValueMapper: (p, i) => i,
                        yValueMapper: (p, _) => p.minor,
                        color: scheme.primary,
                        width: 3,
                        animationDuration: 600,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: Gaps.sm),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(width: 14, height: 3, color: scheme.primary),
                    const SizedBox(width: 5),
                    Text('This month', style: text.labelSmall),
                    const SizedBox(width: Gaps.lg),
                    Container(
                      width: 14,
                      height: 2,
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
                    ),
                    const SizedBox(width: 5),
                    Text('Last month', style: text.labelSmall),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Top categories this period with their movement vs last period.
class _CategoryShift extends ConsumerWidget {
  const _CategoryShift();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spend = ref.watch(spendByCategoryProvider).valueOrNull ?? const [];
    final prev =
        ref.watch(previousSpendByCategoryProvider).valueOrNull ?? const [];
    final categories = ref.watch(categoryMapProvider);
    final formatter = ref.watch(moneyFormatterProvider);
    final currency = ref.watch(appSettingsProvider).homeCurrency;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    if (spend.isEmpty || prev.isEmpty) return const SizedBox.shrink();
    final prevByCat = {for (final e in prev) e.categoryId: e.totalMinor};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: Gaps.sm),
        const SectionHeader(title: 'Vs last month'),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Gaps.lg,
              vertical: Gaps.sm,
            ),
            child: Column(
              children: [
                for (final e in spend.take(5))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    child: Row(
                      children: [
                        IconBadge(
                          icon: AppIcons.resolve(
                            categories[e.categoryId]?.icon ?? 'category',
                          ),
                          color: Color(
                            categories[e.categoryId]?.color ?? 0xFF9E9E9E,
                          ),
                          size: 32,
                          iconSize: 15,
                        ),
                        const SizedBox(width: Gaps.md),
                        Expanded(
                          child: Text(
                            categories[e.categoryId]?.name ?? 'Uncategorized',
                            style: text.bodyMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        _delta(
                          context,
                          e.totalMinor,
                          prevByCat[e.categoryId] ?? 0,
                          formatter,
                          currency,
                          scheme,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _delta(
    BuildContext context,
    int now,
    int before,
    MoneyFormatter formatter,
    String currency,
    ColorScheme scheme,
  ) {
    final text = Theme.of(context).textTheme;
    final diff = now - before;
    final up = diff > 0;
    final color = diff == 0
        ? scheme.onSurfaceVariant
        : up
        ? scheme.expense
        : scheme.income;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          formatter.format(Money(minor: now, currency: currency)),
          style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        Row(
          children: [
            if (diff != 0)
              Icon(
                up ? LucideIcons.arrowUpRight : LucideIcons.arrowDownLeft,
                size: 11,
                color: color,
              ),
            Text(
              diff == 0
                  ? 'same as last month'
                  : formatter.format(
                      Money(minor: diff.abs(), currency: currency),
                    ),
              style: text.labelSmall?.copyWith(color: color),
            ),
          ],
        ),
      ],
    );
  }
}

/// One row of the "Spending by category" list. Parents with subcategories
/// open a child breakdown sheet on tap (#16).
class _SpendRow extends StatelessWidget {
  const _SpendRow({
    required this.spend,
    required this.total,
    required this.currency,
    required this.formatter,
    required this.category,
    required this.hasChildren,
  });

  final CategorySpend spend;
  final int total;
  final String currency;
  final MoneyFormatter formatter;
  final Category? category;
  final bool hasChildren;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          IconBadge(
            icon: AppIcons.resolve(category?.icon ?? 'category'),
            color: Color(category?.color ?? 0xFF9E9E9E),
            size: 32,
            iconSize: 15,
          ),
          const SizedBox(width: Gaps.md),
          Expanded(
            child: Text(
              category?.name ?? 'Uncategorized',
              style: text.bodyMedium,
            ),
          ),
          if (hasChildren) ...[
            Icon(
              LucideIcons.chevronRight,
              size: 14,
              color: scheme.onSurfaceVariant,
            ),
            const SizedBox(width: Gaps.sm),
          ],
          Text(
            '${(spend.totalMinor / total * 100).round()}%',
            style: text.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(width: Gaps.sm),
          AmountText(
            Money(minor: spend.totalMinor, currency: currency),
            formatter: formatter,
            style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );

    if (!hasChildren || category == null) return row;
    return InkWell(
      onTap: () => _showChildBreakdown(context, category!),
      child: row,
    );
  }

  void _showChildBreakdown(BuildContext context, Category parent) {
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      builder: (_) => SafeArea(
        child: Consumer(
          builder: (context, ref, _) {
            final rows =
                ref.watch(spendByChildrenProvider(parent.id)).valueOrNull ??
                const <CategorySpend>[];
            final categories = ref.watch(categoryMapProvider);
            final text = Theme.of(context).textTheme;
            final scheme = Theme.of(context).colorScheme;
            final childTotal = rows.fold(0, (s, e) => s + e.totalMinor);

            return ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.all(Gaps.lg),
              children: [
                Row(
                  children: [
                    IconBadge(
                      icon: AppIcons.resolve(parent.icon),
                      color: Color(parent.color),
                      size: 36,
                      iconSize: 17,
                    ),
                    const SizedBox(width: Gaps.md),
                    Expanded(child: Text(parent.name, style: text.titleMedium)),
                    AmountText(
                      Money(minor: childTotal, currency: currency),
                      formatter: formatter,
                      style: text.titleMedium,
                    ),
                  ],
                ),
                const SizedBox(height: Gaps.md),
                for (final e in rows)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        IconBadge(
                          icon: AppIcons.resolve(
                            e.categoryId == parent.id
                                ? parent.icon
                                : categories[e.categoryId]?.icon ?? 'category',
                          ),
                          color: Color(
                            e.categoryId == parent.id
                                ? parent.color
                                : categories[e.categoryId]?.color ?? 0xFF9E9E9E,
                          ),
                          size: 30,
                          iconSize: 14,
                        ),
                        const SizedBox(width: Gaps.md),
                        Expanded(
                          child: Text(
                            // Direct spend on the parent shows as "General".
                            e.categoryId == parent.id
                                ? 'General'
                                : categories[e.categoryId]?.name ?? 'Unknown',
                            style: text.bodyMedium,
                          ),
                        ),
                        if (childTotal > 0)
                          Text(
                            '${(e.totalMinor / childTotal * 100).round()}%',
                            style: text.labelSmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        const SizedBox(width: Gaps.sm),
                        AmountText(
                          Money(minor: e.totalMinor, currency: currency),
                          formatter: formatter,
                          style: text.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Where the net worth lives: per-account share bars.
class _AccountComposition extends ConsumerWidget {
  const _AccountComposition();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(activeAccountsProvider).valueOrNull ?? const [];
    final formatter = ref.watch(moneyFormatterProvider);
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    final included = accounts
        .where((e) => e.account.includeInNetWorth)
        .toList();
    if (included.length < 2) return const SizedBox.shrink();
    final maxAbs = included.fold<int>(
      1,
      (m, e) => e.balanceMinor.abs() > m ? e.balanceMinor.abs() : m,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: Gaps.sm),
        const SectionHeader(title: 'Where it lives'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(Gaps.lg),
            child: Column(
              children: [
                for (final e in included)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        IconBadge(
                          icon: AppIcons.resolve(e.account.icon),
                          color: Color(e.account.color),
                          size: 32,
                          iconSize: 15,
                        ),
                        const SizedBox(width: Gaps.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      e.account.name,
                                      style: text.bodySmall,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  AmountText(
                                    Money(
                                      minor: e.balanceMinor,
                                      currency: e.account.currency,
                                    ),
                                    formatter: formatter,
                                    tone: e.balanceMinor < 0
                                        ? AmountTone.expense
                                        : AmountTone.neutral,
                                    style: text.bodySmall?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(99),
                                child: LinearProgressIndicator(
                                  value: e.balanceMinor.abs() / maxAbs,
                                  minHeight: 5,
                                  backgroundColor:
                                      scheme.surfaceContainerHighest,
                                  color: e.balanceMinor < 0
                                      ? scheme.expense
                                      : Color(e.account.color),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
