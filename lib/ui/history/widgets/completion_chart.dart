import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/time/time_format.dart';

/// Completion % bars: 12 months (year view) or each day (month view).
class CompletionChart extends StatelessWidget {
  const CompletionChart({super.key, required this.values, required this.isYear});

  /// Null means "no data" and draws no bar.
  final List<double?> values;
  final bool isYear;

  /// Month number (year view) or day of month (month view).
  String _label(int index) => '${index + 1}';

  String _semanticSummary() {
    final known = values.whereType<double>().toList();
    if (known.isEmpty) return 'No completion data for this period.';
    final best = known.reduce((a, b) => a > b ? a : b).round();
    final avg = (known.reduce((a, b) => a + b) / known.length).round();
    return 'Completion chart. Average $avg percent, best $best percent.';
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final barWidth = isYear ? 12.0 : 5.0;

    return Semantics(
      label: _semanticSummary(),
      excludeSemantics: true,
      child: AspectRatio(
        aspectRatio: 1.5,
        child: Padding(
          padding: const EdgeInsets.only(right: AppSpace.sm, top: AppSpace.md),
          child: BarChart(
            BarChartData(
              minY: 0,
              maxY: 100,
              alignment: BarChartAlignment.spaceAround,
              borderData: FlBorderData(
                show: true,
                border: const Border(
                  left: BorderSide(color: AppColors.ink, width: 1),
                  bottom: BorderSide(color: AppColors.ink, width: 1),
                ),
              ),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: 20,
                getDrawingHorizontalLine: (_) => FlLine(color: AppColors.line, strokeWidth: 1),
              ),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  axisNameWidget: Text('%', style: text.labelSmall),
                  axisNameSize: 16,
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: 20,
                    reservedSize: 32,
                    getTitlesWidget: (value, meta) =>
                        Text(value.round().toString(), style: text.labelSmall?.copyWith(color: AppColors.ink)),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 24,
                    getTitlesWidget: (value, meta) {
                      final i = value.round();
                      final show = isYear || i == 0 || (i + 1) % 5 == 0;
                      if (!show) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: AppSpace.xs),
                        child: Text(_label(i), style: text.labelSmall?.copyWith(color: AppColors.ink)),
                      );
                    },
                  ),
                ),
              ),
              barTouchData: BarTouchData(
                enabled: true,
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (_) => AppColors.ink,
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final v = values[group.x];
                    if (v == null) return null;
                    final title = isYear ? TimeFormat.monthShort[group.x] : 'Day ${group.x + 1}';
                    return BarTooltipItem(
                      '$title\n${v.round()}%',
                      const TextStyle(color: AppColors.onPrimary, fontWeight: FontWeight.w600, fontSize: 12),
                    );
                  },
                ),
              ),
              barGroups: [
                for (var i = 0; i < values.length; i++)
                  BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: values[i] ?? 0,
                        width: barWidth,
                        color: (values[i] ?? 0) >= 100 ? AppColors.primaryDark : AppColors.primary,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
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
