import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../providers/dashboard_time_range_provider.dart';

class CaloriesSparkline extends ConsumerWidget {
  final List<({String date, double calories})> entries;

  const CaloriesSparkline({super.key, required this.entries});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timeRange = ref.watch(dashboardTimeRangeProvider);

    if (entries.isEmpty) {
      return const SizedBox(
        height: 200,
        child: Center(child: Text('Log your first food')),
      );
    }

    final sorted = List<({String date, double calories})>.from(entries)
      ..sort((a, b) => a.date.compareTo(b.date));

    final now = DateTime.now();
    final calculatedStart = switch (timeRange) {
      TimeRange.oneMonth => now.subtract(const Duration(days: 30)),
      TimeRange.sixMonths => now.subtract(const Duration(days: 180)),
      TimeRange.allTime => DateTime(2000, 1, 1),
    };

    final earliestData = sorted.isNotEmpty
        ? DateTime.parse(sorted.first.date)
        : now;
    final effectiveStart = earliestData.isAfter(calculatedStart)
        ? earliestData
        : calculatedStart;

    final filtered = sorted.where((e) {
      final date = DateTime.parse(e.date);
      return !date.isBefore(effectiveStart);
    }).toList();

    if (filtered.isEmpty) {
      return const SizedBox(
        height: 200,
        child: Center(child: Text('Log your first food')),
      );
    }

    final refDate = effectiveStart;
    final rawSpots = filtered.map((e) {
      final date = DateTime.parse(e.date);
      final day = date.difference(refDate).inDays.toDouble();
      return FlSpot(day, e.calories);
    }).toList();

    final allCals = rawSpots.map((s) => s.y).toList();
    final minCals = allCals.reduce((a, b) => a < b ? a : b);
    final maxCals = allCals.reduce((a, b) => a > b ? a : b);
    final range = maxCals - minCals;
    final pad = range.clamp(100.0, double.infinity) * 0.15;

    final maxDays = switch (timeRange) {
      TimeRange.oneMonth => 30.0,
      TimeRange.sixMonths => 180.0,
      TimeRange.allTime => rawSpots.isNotEmpty ? rawSpots.last.x : 30.0,
    };

    return SizedBox(
      height: 200,
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 12, 16, 4),
          child: LineChart(
            LineChartData(
              lineBarsData: [
                _rawLine(rawSpots),
              ],
              minX: 0,
              maxX: maxDays,
              minY: (minCals - pad).floorToDouble(),
              maxY: (maxCals + pad).ceilToDouble(),
              clipData: const FlClipData.all(),
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 22,
                    interval: _getInterval(timeRange),
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
                        value.toStringAsFixed(0),
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
                      final day = refDate.add(Duration(days: spot.x.toInt()));
                      final dateStr = DateFormat('M/d/yy').format(day);
                      final val = '${spot.y.toStringAsFixed(0)} cal';
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

  double _getInterval(TimeRange timeRange) {
    return switch (timeRange) {
      TimeRange.oneMonth => 7,
      TimeRange.sixMonths => 30,
      TimeRange.allTime => 60,
    };
  }

  LineChartBarData _rawLine(List<FlSpot> spots) {
    return LineChartBarData(
      spots: spots,
      isCurved: spots.length >= 3,
      preventCurveOverShooting: true,
      color: Colors.blue,
      barWidth: 2.5,
      dotData: FlDotData(
        show: spots.length <= 20,
        getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
          radius: 3,
          color: Colors.blue,
          strokeWidth: 1.5,
          strokeColor: Colors.white,
        ),
      ),
      belowBarData: BarAreaData(show: false),
    );
  }
}
