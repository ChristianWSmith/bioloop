import 'dart:math';

import '../database/database.dart';

enum MaintenanceFailureReason {
  noWeights,
  insufficientPairedData,
}

class MaintenanceResult {
  final double maintenanceCalories;
  final double confidenceInterval;
  final int dataPoints;
  final MaintenanceFailureReason? failureReason;

  MaintenanceResult({
    required this.maintenanceCalories,
    required this.confidenceInterval,
    required this.dataPoints,
    this.failureReason,
  });
}

class MaintenanceCalculator {
  /// Calculates maintenance calories using endpoint averaging model.
  ///
  /// ## Algorithm
  /// 1. Average the first N and last N weight entries (N = min(7, n ~/ 2))
  /// 2. Compute slope = (endAvg - startAvg) / daySpan
  /// 3. maintenance = avgCalories - (slope_lbs/day × 3500)
  /// 4. Confidence interval from raw weight deviation around the interpolated line
  ///
  /// ## Why This Works
  /// Endpoint averaging smooths out daily scale noise and repeated weigh-ins,
  /// giving a clean overall trend. No regression artifacts, no plateau distortion.
  /// All calorie data (including outliers) is preserved — the body absorbs it all.
  ///
  /// ## Minimum Requirements
  /// - ≥5 actual weight entries in the lookback window
  /// - ≥10 day span between first and last weight
  /// - ≥1 day with calorie data
  ///
  /// ## Zero Slope Handling
  /// If the slope is zero (weight stability despite calorie variance),
  /// returns average calories as maintenance with infinite confidence interval.
  static MaintenanceResult? calculate({
    required List<FoodEntry> foodEntries,
    required List<BodyweightEntry> weightEntries,
    int lookbackDays = 90,
    DateTime? now,
  }) {
    final today = now ?? DateTime.now().subtract(const Duration(days: 1));
    final cutoff = today.subtract(Duration(days: lookbackDays));
    final cutoffStr =
        '${cutoff.year}-${cutoff.month.toString().padLeft(2, '0')}-${cutoff.day.toString().padLeft(2, '0')}';
    final todayStr =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    // Aggregate calories by date
    final calByDate = <String, double>{};
    for (final entry in foodEntries) {
      final date = entry.loggedAt.substring(0, 10);
      if (date.compareTo(cutoffStr) >= 0 && date.compareTo(todayStr) <= 0) {
        calByDate[date] = (calByDate[date] ?? 0) + entry.calories;
      }
    }

    // Filter actual weight entries in the lookback window (no forward-fill)
    final sorted = List<BodyweightEntry>.from(weightEntries)
      ..sort((a, b) => a.loggedAt.compareTo(b.loggedAt));

    final actualWeights = <BodyweightEntry>[];
    for (final e in sorted) {
      final date = e.loggedAt.substring(0, 10);
      if (date.compareTo(cutoffStr) >= 0 && date.compareTo(todayStr) <= 0) {
        actualWeights.add(e);
      }
    }

    if (actualWeights.isEmpty) {
      return MaintenanceResult(
        maintenanceCalories: 0,
        confidenceInterval: 0,
        dataPoints: 0,
        failureReason: MaintenanceFailureReason.noWeights,
      );
    }

    // Minimum: 5 actual weights and 10 day span
    if (actualWeights.length < 5) {
      return MaintenanceResult(
        maintenanceCalories: 0,
        confidenceInterval: 0,
        dataPoints: actualWeights.length,
        failureReason: MaintenanceFailureReason.insufficientPairedData,
      );
    }

    final firstDate = DateTime.parse(actualWeights.first.loggedAt.substring(0, 10));
    final lastDate = DateTime.parse(actualWeights.last.loggedAt.substring(0, 10));
    final daySpan = lastDate.difference(firstDate).inDays;

    if (daySpan < 10) {
      return MaintenanceResult(
        maintenanceCalories: 0,
        confidenceInterval: 0,
        dataPoints: actualWeights.length,
        failureReason: MaintenanceFailureReason.insufficientPairedData,
      );
    }

    // Endpoint averaging: average first N and last N entries
    final n = actualWeights.length;
    final windowSize = min(7, n ~/ 2);

    final startAvg = _averageWeight(actualWeights.sublist(0, windowSize));
    final endAvg = _averageWeight(actualWeights.sublist(n - windowSize));

    // Slope: kg/day across the full date span
    final slope = (endAvg - startAvg) / daySpan;

    // Calculate average calories over the weight date range
    double totalCals = 0;
    int calDays = 0;
    for (final entry in calByDate.entries) {
      final date = entry.key;
      final dt = DateTime.parse(date);
      if (!dt.isBefore(firstDate) && !dt.isAfter(lastDate)) {
        totalCals += entry.value;
        calDays++;
      }
    }

    if (calDays == 0) {
      return MaintenanceResult(
        maintenanceCalories: 0,
        confidenceInterval: 0,
        dataPoints: n,
        failureReason: MaintenanceFailureReason.insufficientPairedData,
      );
    }

    final avgCalories = totalCals / calDays;

    // Zero slope: weight is stable
    if (slope.abs() < 1e-6) {
      return MaintenanceResult(
        maintenanceCalories: avgCalories,
        confidenceInterval: double.infinity,
        dataPoints: n,
      );
    }

    // Energy balance: maintenance = avgCalories - (slope_lbs/day × 3500)
    final slopeLbsPerDay = slope * 2.20462;
    final maintenance = avgCalories - (slopeLbsPerDay * 3500);

    // Confidence interval: how much raw weights deviate from the interpolated line
    final startAvgKg = startAvg;
    final endAvgKg = endAvg;
    final firstDayNum = firstDate.millisecondsSinceEpoch.toDouble();
    final lastDayNum = lastDate.millisecondsSinceEpoch.toDouble();
    final lineSlopePerMs = (endAvgKg - startAvgKg) / (lastDayNum - firstDayNum);
    final lineIntercept = startAvgKg;

    double ssRes = 0;
    for (final w in actualWeights) {
      final dayNum = DateTime.parse(w.loggedAt.substring(0, 10))
          .millisecondsSinceEpoch
          .toDouble();
      final predicted = lineIntercept + lineSlopePerMs * (dayNum - firstDayNum);
      ssRes += (w.weightKg - predicted) * (w.weightKg - predicted);
    }
    final stdDev = sqrt(ssRes / n);

    // CI in calorie space: stdDev × 2.20462 × 3500 / daySpan
    // (wider CI = noisier scale readings relative to the trend)
    final ciCalories = stdDev * 2.20462 * 3500 / daySpan;

    return MaintenanceResult(
      maintenanceCalories: maintenance,
      confidenceInterval: ciCalories,
      dataPoints: n,
    );
  }

  static double _averageWeight(List<BodyweightEntry> entries) {
    final sum = entries.fold<double>(0.0, (acc, e) => acc + e.weightKg);
    return sum / entries.length;
  }
}
