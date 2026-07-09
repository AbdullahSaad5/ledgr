import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:ledgr/core/money/money.dart';
import 'package:ledgr/core/money/money_formatter.dart';
import 'package:ledgr/core/providers/repository_providers.dart';
import 'package:ledgr/core/settings/settings_provider.dart';
import 'package:ledgr/core/widgets/amount_text.dart';
import 'package:ledgr/core/widgets/empty_state.dart';
import 'package:ledgr/features/reports/presentation/report_export.dart';

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(selectedPeriodProvider);
    final resolver = ref.watch(periodResolverProvider);
    final label = DateFormat.yMMMM().format(
      DateTime(period.anchorYear, period.anchorMonth),
    );

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Reports'),
          actions: [
            IconButton(
              icon: const Icon(Icons.ios_share),
              tooltip: 'Export CSV',
              onPressed: () => exportPeriodCsv(ref),
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(96),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      onPressed: () =>
                          ref.read(selectedPeriodProvider.notifier).state =
                              resolver.previous(period),
                    ),
                    SizedBox(
                      width: 160,
                      child: Text(label, textAlign: TextAlign.center),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: () =>
                          ref.read(selectedPeriodProvider.notifier).state =
                              resolver.next(period),
                    ),
                  ],
                ),
                const TabBar(
                  tabs: [
                    Tab(text: 'Overview'),
                    Tab(text: 'Trends'),
                    Tab(text: 'Net worth'),
                  ],
                ),
              ],
            ),
          ),
        ),
        body: const TabBarView(
          children: [_OverviewTab(), _TrendsTab(), _NetWorthTab()],
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

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        totals.when(
          loading: () => const SizedBox(
            height: 60,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Text('$e'),
          data: (t) => Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _stat(
                context,
                'Income',
                Money(minor: t.incomeMinor, currency: currency),
                formatter,
                AmountTone.income,
              ),
              _stat(
                context,
                'Expense',
                Money(minor: t.expenseMinor, currency: currency),
                formatter,
                AmountTone.expense,
              ),
              _stat(
                context,
                'Net',
                Money(minor: t.netMinor, currency: currency),
                formatter,
                AmountTone.auto,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        spend.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('$e'),
          data: (items) {
            if (items.isEmpty) {
              return const EmptyState(
                icon: Icons.donut_large,
                title: 'No spending yet',
                message: 'Expenses this month appear here as a breakdown.',
              );
            }
            final total = items.fold(0, (s, e) => s + e.totalMinor);
            return Column(
              children: [
                SizedBox(
                  height: 200,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 50,
                      sections: [
                        for (final e in items)
                          PieChartSectionData(
                            value: e.totalMinor.toDouble(),
                            color: Color(
                              categories[e.categoryId]?.color ?? 0xFF9E9E9E,
                            ),
                            title: '',
                            radius: 40,
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                for (final e in items)
                  Builder(
                    builder: (context) {
                      final money = Money(
                        minor: e.totalMinor,
                        currency: currency,
                      );
                      final pct = (e.totalMinor / total * 100).round();
                      return ListTile(
                        dense: true,
                        leading: CircleAvatar(
                          radius: 8,
                          backgroundColor: Color(
                            categories[e.categoryId]?.color ?? 0xFF9E9E9E,
                          ),
                        ),
                        title: Text(categories[e.categoryId]?.name ?? 'Other'),
                        trailing: Text('${formatter.format(money)}  ·  $pct%'),
                      );
                    },
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        payees.maybeWhen(
          data: (list) => list.isEmpty
              ? const SizedBox.shrink()
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Top payees',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    for (final p in list)
                      ListTile(
                        dense: true,
                        title: Text(p.payee),
                        trailing: AmountText(
                          Money(minor: p.totalMinor, currency: currency),
                          formatter: formatter,
                        ),
                      ),
                  ],
                ),
          orElse: () => const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _stat(
    BuildContext context,
    String label,
    Money money,
    MoneyFormatter formatter,
    AmountTone tone,
  ) {
    return Column(
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 4),
        AmountText(money, formatter: formatter, tone: tone),
      ],
    );
  }
}

class _TrendsTab extends ConsumerWidget {
  const _TrendsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trend = ref.watch(monthlyTrendProvider);
    final scheme = Theme.of(context).colorScheme;

    return trend.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (points) {
        final maxVal = points.fold<double>(
          1,
          (m, p) => [
            m,
            p.incomeMinor.toDouble(),
            p.expenseMinor.toDouble(),
          ].reduce((a, b) => a > b ? a : b),
        );
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Income vs expense (12 months)',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              Expanded(
                child: BarChart(
                  BarChartData(
                    maxY: maxVal * 1.1,
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
                          getTitlesWidget: (value, meta) {
                            final i = value.toInt();
                            if (i < 0 || i >= points.length) {
                              return const SizedBox.shrink();
                            }
                            return Text(
                              DateFormat.MMM().format(
                                DateTime(points[i].year, points[i].month),
                              ),
                              style: Theme.of(context).textTheme.labelSmall,
                            );
                          },
                        ),
                      ),
                    ),
                    gridData: const FlGridData(show: false),
                    borderData: FlBorderData(show: false),
                    barGroups: [
                      for (var i = 0; i < points.length; i++)
                        BarChartGroupData(
                          x: i,
                          barRods: [
                            BarChartRodData(
                              toY: points[i].incomeMinor.toDouble(),
                              color: scheme.tertiary,
                              width: 6,
                              borderRadius: BorderRadius.circular(2),
                            ),
                            BarChartRodData(
                              toY: points[i].expenseMinor.toDouble(),
                              color: scheme.error,
                              width: 6,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _legend(context, scheme.tertiary, 'Income'),
                  const SizedBox(width: 16),
                  _legend(context, scheme.error, 'Expense'),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _legend(BuildContext context, Color color, String label) {
    return Row(
      children: [
        Container(width: 12, height: 12, color: color),
        const SizedBox(width: 4),
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
    final scheme = Theme.of(context).colorScheme;

    return series.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (points) {
        if (points.isEmpty) {
          return const EmptyState(
            icon: Icons.show_chart,
            title: 'No history yet',
            message: 'Net worth over time appears here.',
          );
        }
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Net worth (12 months)',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              Expanded(
                child: LineChart(
                  LineChartData(
                    titlesData: const FlTitlesData(show: false),
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
                          color: scheme.primary.withValues(alpha: 0.15),
                        ),
                        spots: [
                          for (var i = 0; i < points.length; i++)
                            FlSpot(i.toDouble(), points[i].minor.toDouble()),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
