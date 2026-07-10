import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ledgr/core/money/money.dart';
import 'package:ledgr/core/money/money_formatter.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

/// Shared Syncfusion chart styling so every chart in the app reads the same:
/// transparent plot, no borders, quiet dashed gridlines, Manrope labels.

SfCartesianChart cartesian({
  required BuildContext context,
  required List<CartesianSeries<Object?, Object?>> series,
  ChartAxis? xAxis,
  ChartAxis? yAxis,
  TooltipBehavior? tooltip,
  Legend? legend,
  String currency = 'PKR',
}) {
  final scheme = Theme.of(context).colorScheme;
  final labelStyle = Theme.of(
    context,
  ).textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant);
  return SfCartesianChart(
    margin: EdgeInsets.zero,
    plotAreaBorderWidth: 0,
    backgroundColor: Colors.transparent,
    primaryXAxis:
        xAxis ??
        CategoryAxis(
          majorGridLines: const MajorGridLines(width: 0),
          axisLine: const AxisLine(width: 0),
          majorTickLines: const MajorTickLines(size: 0),
          labelStyle: labelStyle,
        ),
    primaryYAxis:
        yAxis ??
        NumericAxis(
          axisLine: const AxisLine(width: 0),
          majorTickLines: const MajorTickLines(size: 0),
          majorGridLines: MajorGridLines(
            width: 1,
            color: scheme.outlineVariant,
            dashArray: const [4, 4],
          ),
          desiredIntervals: 3,
          axisLabelFormatter: (args) => ChartAxisLabel(
            compactMinor(args.value.toInt(), currency),
            labelStyle,
          ),
        ),
    tooltipBehavior: tooltip,
    legend: legend ?? const Legend(isVisible: false),
    series: series,
  );
}

/// Standard tooltip: soft container, theme text.
TooltipBehavior moneyTooltip(
  BuildContext context,
  MoneyFormatter formatter,
  String currency,
) {
  final scheme = Theme.of(context).colorScheme;
  return TooltipBehavior(
    enable: true,
    color: scheme.surfaceContainerHighest,
    textStyle: Theme.of(
      context,
    ).textTheme.labelMedium!.copyWith(color: scheme.onSurface),
    builder: (data, point, series, pointIndex, seriesIndex) {
      final y = point.y?.toInt() ?? 0;
      final label = formatter.format(Money(minor: y, currency: currency));
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: ShapeDecoration(
          color: scheme.surfaceContainerHighest,
          shape: RoundedSuperellipseBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: Text(
          '${point.x}  $label',
          style: Theme.of(
            context,
          ).textTheme.labelMedium?.copyWith(color: scheme.onSurface),
        ),
      );
    },
  );
}

/// Compact axis label for minor units, honoring the currency's scale:
/// PKR (0dp) 1500 minor → "1.5K"; USD (2dp) 150000 minor → "1.5K".
String compactMinor(int minor, String currency) {
  var factor = 1;
  for (var i = 0; i < decimalDigitsFor(currency); i++) {
    factor *= 10;
  }
  final major = minor / factor;
  return NumberFormat.compact().format(major);
}

/// One (label, minor-amount) chart point.
class MoneyPoint {
  const MoneyPoint(this.label, this.minor, {this.color});
  final String label;
  final int minor;
  final Color? color;
}
