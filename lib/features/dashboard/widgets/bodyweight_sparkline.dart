import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/database/database.dart';
import '../../../providers/unit_preferences_provider.dart';

class BodyweightSparkline extends ConsumerWidget {
  final List<BodyweightEntry> entries;

  const BodyweightSparkline({super.key, required this.entries});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(unitPreferencesProvider);
    final useImperial = prefs.useImperial;

    if (entries.isEmpty) {
      return const SizedBox(
        height: 200,
        child: Center(child: Text('Log your first weight')),
      );
    }

    final sorted = List<BodyweightEntry>.from(entries)
      ..sort((a, b) => a.loggedAt.compareTo(b.loggedAt));

    final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
    final recent = sorted.where((e) {
      final date = DateTime.parse(e.loggedAt);
      return !date.isBefore(thirtyDaysAgo);
    }).toList();

    if (recent.isEmpty) {
      return const SizedBox(
        height: 200,
        child: Center(child: Text('Log your first weight')),
      );
    }

    final refDate = thirtyDaysAgo;
    final factor = useImperial ? 2.20462 : 1.0;
    final unitLabel = useImperial ? 'lb' : 'kg';

    final rawSpots = recent.map((e) {
      final date = DateTime.parse(e.loggedAt);
      final day = date.difference(refDate).inDays.toDouble();
      return FlSpot(day, e.weightKg * factor);
    }).toList();

    final trendValues = computeBodyweightTrend(recent);
    List<FlSpot>? trendSpots;
    if (trendValues != null) {
      trendSpots = List.generate(
        rawSpots.length,
        (i) => FlSpot(rawSpots[i].x, trendValues[i] * factor),
      );
    }

    final allW = rawSpots.map((s) => s.y).toList();
    final minW = allW.reduce((a, b) => a < b ? a : b);
    final maxW = allW.reduce((a, b) => a > b ? a : b);
    final range = maxW - minW;
    final pad = range.clamp(1.0, double.infinity) * 0.15;

    return SizedBox(
      height: 200,
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 12, 16, 4),
          child: LineChart(
            LineChartData(
              lineBarsData: [
                _rawLine(rawSpots, unitLabel),
                if (trendSpots != null) _trendLine(trendSpots, unitLabel),
              ],
              minX: 0,
              maxX: 30,
              minY: (minW - pad).floorToDouble(),
              maxY: (maxW + pad).ceilToDouble(),
              clipData: const FlClipData.all(),
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 22,
                    interval: 7,
                    getTitlesWidget: (value, meta) {
                      final day = refDate.add(Duration(days: value.toInt()));
                      return SideTitleWidget(
                        meta: meta,
                        child: Text(
                          DateFormat('M/d').format(day),
                          style: const TextStyle(fontSize: 10),
                        ),
                      );
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 38,
                    getTitlesWidget: (value, meta) {
                      return Text(
                        value.toStringAsFixed(value >= 100 ? 0 : 1),
                        style: const TextStyle(fontSize: 10),
                      );
                    },
                  ),
                ),
                topTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
              ),
              gridData: const FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: null,
              ),
              borderData: FlBorderData(show: false),
              lineTouchData: LineTouchData(
                enabled: rawSpots.isNotEmpty,
                touchTooltipData: LineTouchTooltipData(
                  getTooltipItems: (touchedSpots) {
                    return touchedSpots.map((spot) {
                      final day =
                          refDate.add(Duration(days: spot.x.toInt()));
                      final dateStr = DateFormat('M/d/yy').format(day);
                      final val = useImperial
                          ? '${spot.y.toStringAsFixed(1)} lb'
                          : '${spot.y.toStringAsFixed(1)} kg';
                      return LineTooltipItem(
                        '$dateStr\n$val',
                        const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      );
                    }).toList();
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  LineChartBarData _rawLine(List<FlSpot> spots, String unit) {
    return LineChartBarData(
      spots: spots,
      isCurved: spots.length >= 3,
      preventCurveOverShooting: true,
      color: Colors.blue,
      barWidth: 2.5,
      dotData: FlDotData(
        show: spots.length <= 20,
        getDotPainter: (spot, percent, barData, index) =>
            FlDotCirclePainter(
          radius: 3,
          color: Colors.blue,
          strokeWidth: 1.5,
          strokeColor: Colors.white,
        ),
      ),
      belowBarData: BarAreaData(show: false),
    );
  }

  LineChartBarData _trendLine(List<FlSpot> spots, String unit) {
    return LineChartBarData(
      spots: spots,
      isCurved: true,
      preventCurveOverShooting: true,
      color: Colors.blue.withValues(alpha: 0.4),
      barWidth: 1.5,
      dashArray: [5, 4],
      dotData: const FlDotData(show: false),
      belowBarData: BarAreaData(show: false),
    );
  }
}

@visibleForTesting
List<double>? computeBodyweightTrend(List<BodyweightEntry> sortedAsc) {
  if (sortedAsc.length < 7) return null;

  final dates =
      sortedAsc.map((e) => DateTime.parse(e.loggedAt)).toList();
  final weights = sortedAsc.map((e) => e.weightKg).toList();
  final epoch = DateTime(2000, 1, 1);
  final dayNums =
      dates.map((d) => d.difference(epoch).inDays.toDouble()).toList();

  final trend = <double>[];
  for (int i = 0; i < sortedAsc.length; i++) {
    final center = dates[i];
    final lo = center.subtract(const Duration(days: 3));
    final hi = center.add(const Duration(days: 3));

    final xs = <double>[];
    final ys = <double>[];
    for (int j = 0; j < sortedAsc.length; j++) {
      if (!dates[j].isBefore(lo) && !dates[j].isAfter(hi)) {
        xs.add(dayNums[j]);
        ys.add(weights[j]);
      }
    }

    if (xs.length < 3) {
      trend.add(weights[i]);
      continue;
    }

    final n = xs.length;
    double sumX = 0, sumY = 0, sumXY = 0, sumX2 = 0;
    for (int k = 0; k < n; k++) {
      sumX += xs[k];
      sumY += ys[k];
      sumXY += xs[k] * ys[k];
      sumX2 += xs[k] * xs[k];
    }

    final denom = n * sumX2 - sumX * sumX;
    if (denom == 0) {
      trend.add(weights[i]);
      continue;
    }

    final slope = (n * sumXY - sumX * sumY) / denom;
    final intercept = (sumY - slope * sumX) / n;

    trend.add(intercept + slope * dayNums[i]);
  }

  return trend;
}
