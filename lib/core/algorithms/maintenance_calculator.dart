import 'dart:math';

import '../database/database.dart';

class MaintenanceResult {
  final double maintenanceCalories;
  final double confidenceInterval;
  final int dataPoints;

  MaintenanceResult({
    required this.maintenanceCalories,
    required this.confidenceInterval,
    required this.dataPoints,
  });
}

class MaintenanceCalculator {
  static MaintenanceResult? calculate({
    required List<FoodEntry> foodEntries,
    required List<BodyweightEntry> weightEntries,
    int lookbackDays = 30,
    DateTime? now,
  }) {
    final today = now ?? DateTime.now();
    final cutoff = today.subtract(Duration(days: lookbackDays));
    final cutoffStr =
        '${cutoff.year}-${cutoff.month.toString().padLeft(2, '0')}-${cutoff.day.toString().padLeft(2, '0')}';

    final calByDate = <String, double>{};
    for (final entry in foodEntries) {
      final date = entry.loggedAt.substring(0, 10);
      if (date.compareTo(cutoffStr) >= 0) {
        calByDate[date] = (calByDate[date] ?? 0) + entry.calories;
      }
    }

    final sorted = List<BodyweightEntry>.from(weightEntries)
      ..sort((a, b) => a.loggedAt.compareTo(b.loggedAt));

    final recentWeights = <BodyweightEntry>[];
    final recentDates = <String>[];
    for (final e in sorted) {
      final date = e.loggedAt.substring(0, 10);
      if (date.compareTo(cutoffStr) >= 0) {
        recentWeights.add(e);
        recentDates.add(date);
      }
    }

    if (recentWeights.length < 7) return null;

    final epoch = DateTime(2000, 1, 1);
    final dates =
        recentWeights.map((e) => DateTime.parse(e.loggedAt)).toList();
    final dayNums =
        dates.map((d) => d.difference(epoch).inDays.toDouble()).toList();
    final weights = recentWeights.map((e) => e.weightKg).toList();

    final pairedAvgCals = <double>[];
    final pairedChanges = <double>[];

    for (int i = 0; i < recentWeights.length; i++) {
      final center = dates[i];
      final lo = center.subtract(const Duration(days: 3));
      final hi = center.add(const Duration(days: 3));

      final xs = <double>[];
      final ys = <double>[];
      final windowDates = <String>[];
      for (int j = 0; j < recentWeights.length; j++) {
        if (!dates[j].isBefore(lo) && !dates[j].isAfter(hi)) {
          xs.add(dayNums[j]);
          ys.add(weights[j]);
          windowDates.add(recentDates[j]);
        }
      }

      if (xs.length < 3) continue;

      final n = xs.length;
      double sumX = 0, sumY = 0, sumXY = 0, sumX2 = 0;
      for (int k = 0; k < n; k++) {
        sumX += xs[k];
        sumY += ys[k];
        sumXY += xs[k] * ys[k];
        sumX2 += xs[k] * xs[k];
      }

      final denom = n * sumX2 - sumX * sumX;
      if (denom.abs() < 1e-10) continue;

      final slope = (n * sumXY - sumX * sumY) / denom;

      double sumCals = 0;
      int calDays = 0;
      for (final d in windowDates) {
        final c = calByDate[d];
        if (c != null && c > 0) {
          sumCals += c;
          calDays++;
        }
      }

      if (calDays < 3) continue;

      pairedAvgCals.add(sumCals / calDays);
      pairedChanges.add(slope);
    }

    if (pairedAvgCals.length < 14) return null;

    final np = pairedAvgCals.length;
    double sx = 0, sy = 0, sxy = 0, sx2 = 0;
    for (int i = 0; i < np; i++) {
      sx += pairedAvgCals[i];
      sy += pairedChanges[i];
      sxy += pairedAvgCals[i] * pairedChanges[i];
      sx2 += pairedAvgCals[i] * pairedAvgCals[i];
    }

    final mx = sx / np;
    final my = sy / np;

    final denom2 = np * sx2 - sx * sx;
    if (denom2.abs() < 1e-10) return null;

    final rSlope = (np * sxy - sx * sy) / denom2;
    if (rSlope.abs() < 1e-10) return null;

    final rIntercept = my - rSlope * mx;
    final maintenance = -rIntercept / rSlope;

    double ssRes = 0;
    for (int i = 0; i < np; i++) {
      final predicted = rIntercept + rSlope * pairedAvgCals[i];
      ssRes +=
          (pairedChanges[i] - predicted) * (pairedChanges[i] - predicted);
    }
    final see = sqrt(ssRes / (np - 2));
    final ci = see / rSlope.abs();

    return MaintenanceResult(
      maintenanceCalories: maintenance,
      confidenceInterval: ci,
      dataPoints: np,
    );
  }
}
