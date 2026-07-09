import 'package:fl_chart/fl_chart.dart';
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
import 'package:ledgr/core/widgets/amount_text.dart';
import 'package:ledgr/core/widgets/app_icons.dart';
import 'package:ledgr/core/widgets/empty_state.dart';
import 'package:ledgr/core/widgets/icon_badge.dart';
import 'package:ledgr/core/widgets/insight_tile.dart';
import 'package:ledgr/core/widgets/ledgr_header.dart';
import 'package:ledgr/core/widgets/period_switcher.dart';
import 'package:ledgr/core/widgets/section_header.dart';
import 'package:ledgr/core/widgets/soft_icon_button.dart';
import 'package:ledgr/core/widgets/stat_card.dart';
import 'package:ledgr/features/reports/domain/report_models.dart';
import 'package:ledgr/features/reports/presentation/report_export.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

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
                    onPressed: () => exportPeriodCsv(ref),
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
                                PieChart(
                                  PieChartData(
                                    sectionsSpace: 3,
                                    centerSpaceRadius: 56,
                                    sections: [
                                      for (final e in items)
                                        PieChartSectionData(
                                          value: e.totalMinor.toDouble(),
                                          color: Color(
                                            categories[e.categoryId]?.color ??
                                                0xFF9E9E9E,
                                          ),
                                          title: '',
                                          radius: 30,
                                        ),
                                    ],
                                  ),
                                ),
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'Spent',
                                      style: text.labelSmall?.copyWith(
                                        color: scheme.onSurfaceVariant,
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
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 5),
                              child: Row(
                                children: [
                                  IconBadge(
                                    icon: AppIcons.resolve(
                                      categories[e.categoryId]?.icon ??
                                          'category',
                                    ),
                                    color: Color(
                                      categories[e.categoryId]?.color ??
                                          0xFF9E9E9E,
                                    ),
                                    size: 32,
                                    iconSize: 15,
                                  ),
                                  const SizedBox(width: Gaps.md),
                                  Expanded(
                                    child: Text(
                                      categories[e.categoryId]?.name ?? 'Other',
                                      style: text.bodyMedium,
                                    ),
                                  ),
                                  Text(
                                    '${(e.totalMinor / total * 100).round()}%',
                                    style: text.labelSmall?.copyWith(
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(width: Gaps.sm),
                                  AmountText(
                                    Money(
                                      minor: e.totalMinor,
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
    final text = Theme.of(context).textTheme;
    final maxVal = points.fold<double>(
      1,
      (m, p) => [
        m,
        p.incomeMinor.toDouble(),
        p.expenseMinor.toDouble(),
      ].reduce((a, b) => a > b ? a : b),
    );

    return Column(
      children: [
        SizedBox(
          height: 210,
          child: BarChart(
            BarChartData(
              maxY: maxVal * 1.15,
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (_) => scheme.surfaceContainerHighest,
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final p = points[group.x];
                    final label = rodIndex == 0 ? 'In' : 'Out';
                    final minor = rodIndex == 0
                        ? p.incomeMinor
                        : p.expenseMinor;
                    final money = formatter.format(
                      Money(minor: minor, currency: currency),
                    );
                    return BarTooltipItem(
                      '$label $money',
                      text.labelMedium!.copyWith(color: scheme.onSurface),
                    );
                  },
                ),
              ),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 42,
                    interval: maxVal <= 1 ? 1 : maxVal / 3,
                    getTitlesWidget: (value, meta) => Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Text(
                        _compactMinor(value.toInt()),
                        style: text.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      final i = value.toInt();
                      if (i < 0 || i >= points.length) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          DateFormat.MMM().format(
                            DateTime(points[i].year, points[i].month),
                          ),
                          style: text.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              gridData: FlGridData(
                drawVerticalLine: false,
                horizontalInterval: maxVal <= 1 ? 1 : maxVal / 3,
                getDrawingHorizontalLine: (v) => FlLine(
                  color: scheme.outlineVariant,
                  strokeWidth: 1,
                  dashArray: [4, 4],
                ),
              ),
              borderData: FlBorderData(show: false),
              barGroups: [
                for (var i = 0; i < points.length; i++)
                  BarChartGroupData(
                    x: i,
                    barsSpace: 3,
                    barRods: [
                      BarChartRodData(
                        toY: points[i].incomeMinor.toDouble(),
                        color: scheme.income,
                        width: 9,
                        borderRadius: BorderRadius.circular(3),
                      ),
                      BarChartRodData(
                        toY: points[i].expenseMinor.toDouble(),
                        color: scheme.expense,
                        width: 9,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ],
                  ),
              ],
            ),
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
                      child: LineChart(
                        LineChartData(
                          lineTouchData: LineTouchData(
                            touchTooltipData: LineTouchTooltipData(
                              getTooltipColor: (_) =>
                                  scheme.surfaceContainerHighest,
                              getTooltipItems: (spots) => [
                                for (final spot in spots)
                                  LineTooltipItem(
                                    formatter.format(
                                      Money(
                                        minor: spot.y.toInt(),
                                        currency: currency,
                                      ),
                                    ),
                                    text.labelMedium!.copyWith(
                                      color: scheme.onSurface,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          titlesData: FlTitlesData(
                            leftTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            topTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            rightTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                interval: (points.length / 4)
                                    .ceilToDouble()
                                    .clamp(1, 12),
                                getTitlesWidget: (value, meta) {
                                  final i = value.toInt();
                                  if (i < 0 || i >= points.length) {
                                    return const SizedBox.shrink();
                                  }
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      DateFormat.MMM().format(points[i].date),
                                      style: text.labelSmall?.copyWith(
                                        color: scheme.onSurfaceVariant,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          gridData: const FlGridData(show: false),
                          borderData: FlBorderData(show: false),
                          lineBarsData: [
                            LineChartBarData(
                              isCurved: true,
                              preventCurveOverShooting: true,
                              color: scheme.primary,
                              barWidth: 3,
                              dotData: const FlDotData(show: false),
                              belowBarData: BarAreaData(
                                show: true,
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    scheme.primary.withValues(alpha: 0.22),
                                    scheme.primary.withValues(alpha: 0),
                                  ],
                                ),
                              ),
                              spots: [
                                for (var i = 0; i < points.length; i++)
                                  FlSpot(
                                    i.toDouble(),
                                    points[i].minor.toDouble(),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Compact axis label for minor units: 150000 minor (Rs 1,500.00) → "1.5K".
String _compactMinor(int minor) {
  final major = minor / 100;
  return NumberFormat.compact().format(major);
}
