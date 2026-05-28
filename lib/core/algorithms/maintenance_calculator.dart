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
  /// Calculates maintenance calories using rolling linear regression.
  ///
  /// ## Forward-Fill Behavior
  /// - Dates with actual weight entries use the logged weight
  /// - Dates between first and last weight use last-known weight (forward-fill)
  /// - **Dates before first weight entry use the oldest weight** (assumes no change prior to onboarding)
  /// - Dates after last weight (up to yesterday) use last-known weight
  ///
  /// This ensures new users with sparse early data can still get maintenance estimates.
  /// The algorithm assumes weight stability before the first logged weight.
  ///
  /// ## Primary Regression Requirements
  /// - Minimum 7 weight points in 30-day window (after forward-fill)
  /// - Minimum 14 paired (calories, weight-slope) data points
  /// - Minimum 10 actual weight entries
  ///
  /// ## Fallback: Rolling Average Trend
  /// When regression fails (insufficient paired data < 14 points or < 10 actual weights),
  /// falls back to a rolling average trend method that calculates overall weight change.
  ///
  /// **Rolling average minimum requirements**:
  /// - 7 total days in the lookback window
  /// - 3 actual weight measurements (not forward-filled)
  ///
  /// ## Zero Slope Handling
  /// If the regression slope is zero (weight stability despite calorie variance),
  /// returns average calories as maintenance with infinite confidence interval.
  static MaintenanceResult? calculate({
    required List<FoodEntry> foodEntries,
    required List<BodyweightEntry> weightEntries,
    int lookbackDays = 30,
    DateTime? now,
  }) {
    final today = now ?? DateTime.now().subtract(const Duration(days: 1));
    final cutoff = today.subtract(Duration(days: lookbackDays));
    final cutoffStr =
        '${cutoff.year}-${cutoff.month.toString().padLeft(2, '0')}-${cutoff.day.toString().padLeft(2, '0')}';
    final todayStr =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    final calByDate = <String, double>{};
    for (final entry in foodEntries) {
      final date = entry.loggedAt.substring(0, 10);
      if (date.compareTo(cutoffStr) >= 0 && date.compareTo(todayStr) <= 0) {
        calByDate[date] = (calByDate[date] ?? 0) + entry.calories;
      }
    }

    final sorted = List<BodyweightEntry>.from(weightEntries)
      ..sort((a, b) => a.loggedAt.compareTo(b.loggedAt));

    var recentWeights = <BodyweightEntry>[];
    var recentDates = <String>[];
    for (final e in sorted) {
      final date = e.loggedAt.substring(0, 10);
      if (date.compareTo(cutoffStr) >= 0) {
        recentWeights.add(e);
        recentDates.add(date);
      }
    }

    // Forward-fill: ensure every day has a weight entry
    final dateMap = <String, double>{};
    for (final w in recentWeights) {
      final date = w.loggedAt.substring(0, 10);
      dateMap[date] = w.weightKg;
    }

    final start = DateTime.parse(cutoffStr);
    final end = today;
    final filledWeights = <BodyweightEntry>[];

    // Initialize to oldest weight so all prior dates use this assumption
    final oldestWeight = recentWeights.isNotEmpty ? recentWeights.first.weightKg : null;
    double? lastKnownWeight = oldestWeight;
    for (int d = 0; d <= end.difference(start).inDays; d++) {
      final date = start.add(Duration(days: d));
      final dateStr =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      if (dateMap.containsKey(dateStr)) {
        lastKnownWeight = dateMap[dateStr]!;
      }
      if (lastKnownWeight != null) {
        filledWeights.add(BodyweightEntry(
          id: -1,
          weightKg: lastKnownWeight,
          loggedAt: dateStr,
        ));
      }
    }

    recentWeights = filledWeights;
    recentDates = filledWeights.map((e) => e.loggedAt.substring(0, 10)).toList();

    if (recentWeights.length < 7) {
      return MaintenanceResult(
        maintenanceCalories: 0,
        confidenceInterval: 0,
        dataPoints: 0,
        failureReason: MaintenanceFailureReason.noWeights,
      );
    }

    // Count actual calendar days with both weight and calorie data
    int pairedDayCount = 0;
    for (final w in filledWeights) {
      if (calByDate.containsKey(w.loggedAt.substring(0, 10))) {
        pairedDayCount++;
      }
    }

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

    if (pairedAvgCals.length < 14 || weightEntries.length < 10) {
      // Sparse data (< 14 paired points or < 10 actual weights) — use rolling average trend fallback
      // Primary regression is unreliable with forward-filled plateaus
      final trendResult = _calculateRollingAverageTrend(
        foodEntries: foodEntries,
        weightEntries: weightEntries,
        calByDate: calByDate,
        start: start,
        end: end,
      );
      if (trendResult != null) {
        return trendResult;
      }
      // Fallback failed, return failure
      return MaintenanceResult(
        maintenanceCalories: 0,
        confidenceInterval: 0,
        dataPoints: pairedDayCount,
        failureReason: MaintenanceFailureReason.insufficientPairedData,
      );
    }

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
    final rSlope = denom2.abs() < 1e-10 ? 0 : (np * sxy - sx * sy) / denom2;
    if (rSlope.abs() < 1e-10) {
      // Regression found zero slope — try rolling average trend fallback
      final trendResult = _calculateRollingAverageTrend(
        foodEntries: foodEntries,
        weightEntries: weightEntries,
        calByDate: calByDate,
        start: start,
        end: end,
      );
      if (trendResult != null) {
        return trendResult;
      }
      // Fallback failed, return average calories as maintenance
      final avgCalories = sx / np;
      return MaintenanceResult(
        maintenanceCalories: avgCalories,
        confidenceInterval: double.infinity,
        dataPoints: np,
      );
    }

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

  /// Calculates maintenance using rolling average trend method.
  ///
  /// This is a fallback for when the primary regression fails due to
  /// insufficient paired data or zero slope. It uses the actual weight
  /// measurements (not forward-filled) to calculate the overall trend.
  ///
  /// ## Algorithm
  /// 1. Compare first-N vs last-N actual weight measurements
  /// 2. Calculate daily rate from the difference
  /// 3. maintenance = avgCalories - (slope_kg_per_day × 2.20462 × 3500)
  ///    (Note: negative slope = weight loss = maintenance > intake, so we subtract)
  ///
  /// ## Returns
  /// - MaintenanceResult with trend-based estimate, or null if insufficient data
  static MaintenanceResult? _calculateRollingAverageTrend({
    required List<FoodEntry> foodEntries,
    required List<BodyweightEntry> weightEntries,
    required Map<String, double> calByDate,
    required DateTime start,
    required DateTime end,
  }) {
    final totalDays = end.difference(start).inDays + 1;
    // Need at least 7 days for meaningful trend
    if (totalDays < 7) return null;
    
    // Filter to actual weight entries in the date range
    final cutoffStr =
        '${start.year}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')}';
    final endStr =
        '${end.year}-${end.month.toString().padLeft(2, '0')}-${end.day.toString().padLeft(2, '0')}';
    
    final actualWeights = weightEntries.where((w) {
      final date = w.loggedAt.substring(0, 10);
      return date.compareTo(cutoffStr) >= 0 && date.compareTo(endStr) <= 0;
    }).toList();
    
    // Need at least 3 actual measurements
    if (actualWeights.length < 3) return null;
    
    // Sort by date
    actualWeights.sort((a, b) => a.loggedAt.compareTo(b.loggedAt));
    
    // Calculate average of first third and last third of measurements
    final third = (actualWeights.length / 3).clamp(1, actualWeights.length ~/ 2).toInt();
    final firstThird = actualWeights.sublist(0, third);
    final lastThird = actualWeights.sublist(actualWeights.length - third);
    
    final avgFirstWeight = firstThird.fold<double>(
      0.0,
      (sum, w) => sum + w.weightKg,
    ) / firstThird.length;
    
    final avgLastWeight = lastThird.fold<double>(
      0.0,
      (sum, w) => sum + w.weightKg,
    ) / lastThird.length;
    
    // Calculate days between midpoints
    final firstDate = DateTime.parse(firstThird.first.loggedAt);
    final lastDate = DateTime.parse(lastThird.last.loggedAt);
    final daysBetween = lastDate.difference(firstDate).inDays;
    
    if (daysBetween < 1) return null;
    
    // Calculate slope (kg per day)
    final weightChange = avgLastWeight - avgFirstWeight;
    final slope = weightChange / daysBetween;
    
    // Calculate average calories over the period
    double totalCals = 0;
    int calDays = 0;
    for (final cals in calByDate.values) {
      totalCals += cals;
      calDays++;
    }
    if (calDays == 0) return null;
    final avgCalories = totalCals / calDays;
    
    // Check for near-zero slope (weight stability)
    if (slope.abs() < 1e-6) {
      // Weight is stable — return average calories with infinite confidence
      return MaintenanceResult(
        maintenanceCalories: avgCalories,
        confidenceInterval: double.infinity,
        dataPoints: actualWeights.length,
      );
    }
    
    final slopeLbsPerDay = slope * 2.20462;

    // Calculate maintenance from trend
    // Negative slope (weight loss) → maintenance = intake + deficit
    // Positive slope (weight gain) → maintenance = intake - surplus
    // Formula: maintenance = avgCalories - (slope_lbs_per_day × 3500)
    final maintenance = avgCalories - (slopeLbsPerDay * 3500);

    // Calculate confidence interval based on data quality
    // More measurements = narrower CI
    final baseCI = 500.0 / actualWeights.length;
    // Adjust for measurement spread (more days = more confidence)
    final spreadFactor = 1.0 + (10.0 / daysBetween);
    final confidenceInterval = baseCI * spreadFactor;

    return MaintenanceResult(
      maintenanceCalories: maintenance,
      confidenceInterval: confidenceInterval,
      dataPoints: actualWeights.length,
    );
  }
}
