import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:ledgr/app/theme/app_theme.dart';
import 'package:ledgr/core/money/money.dart';
import 'package:ledgr/core/providers/repository_providers.dart';
import 'package:ledgr/core/settings/settings_provider.dart';
import 'package:ledgr/core/widgets/amount_text.dart';
import 'package:ledgr/core/widgets/empty_state.dart';
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
                            child: PieChart(
                              PieChartData(
                                sectionsSpace: 3,
                                centerSpaceRadius: 52,
                                sections: [
                                  for (final e in items)
                                    PieChartSectionData(
                                      value: e.totalMinor.toDouble(),
                                      color: Color(
                                        categories[e.categoryId]?.color ??
                                            0xFF9E9E9E,
                                      ),
                                      title: '',
                                      radius: 34,
                                    ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: Gaps.md),
                          for (final e in items)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 5),
                              child: Row(
                                children: [
                                  Container(
                                    width: 9,
                                    height: 9,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Color(
                                        categories[e.categoryId]?.color ??
                                            0xFF9E9E9E,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: Gaps.sm),
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
          padding: const EdgeInsets.fromLTRB(
            Gaps.page,
            Gaps.md,
            Gaps.page,
            120,
          ),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(Gaps.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Income vs expense (12 months)',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: Gaps.lg),
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
                ],
              ),
            ),
          ),
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
    final scheme = Theme.of(context).colorScheme;

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
        return Padding(
          padding: const EdgeInsets.fromLTRB(
            Gaps.page,
            Gaps.md,
            Gaps.page,
            120,
          ),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(Gaps.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Net worth (12 months)',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: Gaps.lg),
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
        );
      },
    );
  }
}
