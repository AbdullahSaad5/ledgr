import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:ledgr/app/theme/app_theme.dart';
import 'package:ledgr/core/money/money.dart';
import 'package:ledgr/core/money/money_formatter.dart';
import 'package:ledgr/core/providers/repository_providers.dart';
import 'package:ledgr/core/settings/settings_provider.dart';
import 'package:ledgr/core/widgets/amount_text.dart';
import 'package:ledgr/core/widgets/app_icons.dart';
import 'package:ledgr/core/widgets/empty_state.dart';
import 'package:ledgr/core/widgets/icon_badge.dart';
import 'package:ledgr/core/widgets/ledgr_header.dart';
import 'package:ledgr/core/widgets/period_switcher.dart';
import 'package:ledgr/core/widgets/section_header.dart';
import 'package:ledgr/core/widgets/soft_icon_button.dart';
import 'package:ledgr/core/widgets/stat_card.dart';
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
    final formatter = ref.watch(moneyFormatterProvider);
    final currency = ref.watch(appSettingsProvider).homeCurrency;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return trend.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (points) {
        final active = points
            .where((p) => p.incomeMinor != 0 || p.expenseMinor != 0)
            .toList();
        if (active.isEmpty) {
          return const EmptyState(
            icon: LucideIcons.barChart3,
            title: 'No history yet',
            message: 'Once you log a few months, trends show up here.',
          );
        }
        final totalSpent = active.fold(0, (s, p) => s + p.expenseMinor);
        final avgSpent = totalSpent ~/ active.length;
        final maxVal = points.fold<double>(
          1,
          (m, p) => [
            m,
            p.incomeMinor.toDouble(),
            p.expenseMinor.toDouble(),
          ].reduce((a, b) => a > b ? a : b),
        );

        return ListView(
          padding: const EdgeInsets.only(top: Gaps.md, bottom: 120),
          children: [
            StatCard(
              formatter: formatter,
              items: [
                StatItem(
                  label: 'Avg spent / month',
                  money: Money(minor: avgSpent, currency: currency),
                  tone: AmountTone.expense,
                ),
                StatItem(
                  label: 'Avg saved / month',
                  money: Money(
                    minor:
                        active.fold(0, (s, p) => s + p.netMinor) ~/
                        active.length,
                    currency: currency,
                  ),
                  tone: AmountTone.auto,
                ),
              ],
            ),
            const SectionHeader(title: 'Income vs expense'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Gaps.page),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Gaps.sm,
                    Gaps.xl,
                    Gaps.lg,
                    Gaps.lg,
                  ),
                  child: Column(
                    children: [
                      SizedBox(
                        height: 220,
                        child: BarChart(
                          BarChartData(
                            maxY: maxVal * 1.15,
                            barTouchData: BarTouchData(
                              touchTooltipData: BarTouchTooltipData(
                                getTooltipColor: (_) =>
                                    scheme.surfaceContainerHighest,
                                getTooltipItem:
                                    (group, groupIndex, rod, rodIndex) {
                                      final p = points[group.x];
                                      final label = rodIndex == 0
                                          ? 'In'
                                          : 'Out';
                                      final minor = rodIndex == 0
                                          ? p.incomeMinor
                                          : p.expenseMinor;
                                      final money = formatter.format(
                                        Money(minor: minor, currency: currency),
                                      );
                                      return BarTooltipItem(
                                        '$label $money',
                                        text.labelMedium!.copyWith(
                                          color: scheme.onSurface,
                                        ),
                                      );
                                    },
                              ),
                            ),
                            titlesData: FlTitlesData(
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 40,
                                  interval: maxVal <= 1 ? 1 : maxVal / 3,
                                  getTitlesWidget: (value, meta) => Text(
                                    _compactMinor(value.toInt()),
                                    style: text.labelSmall?.copyWith(
                                      color: scheme.onSurfaceVariant,
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
                                    if (points.length > 6 && i.isOdd) {
                                      return const SizedBox.shrink();
                                    }
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        DateFormat.MMM().format(
                                          DateTime(
                                            points[i].year,
                                            points[i].month,
                                          ),
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
                                  barsSpace: 2,
                                  barRods: [
                                    BarChartRodData(
                                      toY: points[i].incomeMinor.toDouble(),
                                      color: scheme.income,
                                      width: 6,
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                    BarChartRodData(
                                      toY: points[i].expenseMinor.toDouble(),
                                      color: scheme.expense,
                                      width: 6,
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
                      const SizedBox(height: 4),
                      Text(
                        'Tap a bar for the exact amount',
                        style: text.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
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
        final first = points.first.minor;
        final delta = current - first;
        final up = delta >= 0;
        final deltaColor = up ? scheme.income : scheme.expense;

        return ListView(
          padding: const EdgeInsets.only(top: Gaps.md, bottom: 120),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Gaps.page),
              child: Card(
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
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          AmountText(
                            Money(minor: current, currency: currency),
                            formatter: formatter,
                            style: text.headlineSmall,
                          ),
                          const SizedBox(width: Gaps.md),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 3),
                            child: Row(
                              children: [
                                Icon(
                                  up
                                      ? LucideIcons.arrowUpRight
                                      : LucideIcons.arrowDownLeft,
                                  size: 14,
                                  color: deltaColor,
                                ),
                                Text(
                                  _deltaLabel(
                                    formatter,
                                    delta,
                                    currency,
                                    points.length,
                                  ),
                                  style: text.labelSmall?.copyWith(
                                    color: deltaColor,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
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
            ),
          ],
        );
      },
    );
  }
}

String _deltaLabel(
  MoneyFormatter formatter,
  int delta,
  String currency,
  int months,
) {
  final money = formatter.format(Money(minor: delta.abs(), currency: currency));
  return '$money over $months months';
}

/// Compact axis label for minor units: 150000 minor (Rs 1,500.00) → "1.5K".
String _compactMinor(int minor) {
  final major = minor / 100;
  return NumberFormat.compact().format(major);
}
