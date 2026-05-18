import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../providers/shared_dashboard_range_provider.dart';

class CaloriesSparkline extends ConsumerWidget {
  final List<({String date, double calories})> entries;
  final DashboardRange range;

  const CaloriesSparkline({
    super.key,
    required this.entries,
    required this.range,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (entries.isEmpty) {
      return const SizedBox(
        height: 200,
        child: Center(child: Text('Log your first food')),
      );
    }

    final sorted = List<({String date, double calories})>.from(entries)
      ..sort((a, b) => a.date.compareTo(b.date));

    final filtered = sorted.where((e) {
      final date = DateTime.parse(e.date);
      return !date.isBefore(range.start);
    }).toList();

    if (filtered.isEmpty) {
      return const SizedBox(
        height: 200,
        child: Center(child: Text('Log your first food')),
      );
    }

    final refDate = range.start;
    final rawSpots = filtered.map((e) {
      final date = DateTime.parse(e.date);
      final day = date.difference(refDate).inDays.toDouble();
      return FlSpot(day, e.calories);
    }).toList();

    final allCals = rawSpots.map((s) => s.y).toList();
    final minCals = allCals.reduce((a, b) => a < b ? a : b);
    final maxCals = allCals.reduce((a, b) => a > b ? a : b);
    final range_ = maxCals - minCals;
    final pad = range_.clamp(100.0, double.infinity) * 0.15;

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
              maxX: range.maxDays,
              minY: (minCals - pad).floorToDouble(),
              maxY: (maxCals + pad).ceilToDouble(),
              clipData: const FlClipData.all(),
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 22,
                    interval: range.xInterval.toDouble(),
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
