import 'dashboard_time_range_provider.dart';

import '../core/database/database.dart';

class DashboardRange {
  final DateTime start;
  final DateTime end;
  final double maxDays;
  final int xInterval;

  const DashboardRange({
    required this.start,
    required this.end,
    required this.maxDays,
    required this.xInterval,
  });

  static DashboardRange compute({
    required TimeRange timeRange,
    required List<BodyweightEntry> weights,
    required List<({String date, double calories})> calories,
  }) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final calculatedStart = switch (timeRange) {
      TimeRange.oneMonth => now.subtract(const Duration(days: 30)),
      TimeRange.sixMonths => now.subtract(const Duration(days: 180)),
      TimeRange.allTime => DateTime(2000, 1, 1),
    };

    DateTime? earliestWeight;
    DateTime? latestWeight;
    if (weights.isNotEmpty) {
      final sorted = List<BodyweightEntry>.from(weights)
        ..sort((a, b) => a.loggedAt.compareTo(b.loggedAt));
      earliestWeight = DateTime.parse(sorted.first.loggedAt);
      latestWeight = DateTime.parse(sorted.last.loggedAt);
    }

    DateTime? earliestCalorie;
    DateTime? latestCalorie;
    if (calories.isNotEmpty) {
      final sorted = List<({String date, double calories})>.from(calories)
        ..sort((a, b) => a.date.compareTo(b.date));
      earliestCalorie = DateTime.parse(sorted.first.date);
      latestCalorie = DateTime.parse(sorted.last.date);
    }

    final earliestData = [earliestWeight, earliestCalorie]
        .whereType<DateTime>()
        .fold<DateTime?>(
          null,
          (prev, curr) => prev == null || curr.isBefore(prev) ? curr : prev,
        );

    final latestData = [latestWeight, latestCalorie]
        .whereType<DateTime>()
        .fold<DateTime?>(
          null,
          (prev, curr) => prev == null || curr.isAfter(prev) ? curr : prev,
        );

    final effectiveStart = earliestData != null && earliestData.isAfter(calculatedStart)
        ? earliestData
        : calculatedStart;

    final effectiveEndCandidates = [latestData, today].whereType<DateTime>();
    final effectiveEnd = effectiveEndCandidates.isEmpty
        ? today
        : effectiveEndCandidates.reduce(
            (a, b) => a.isAfter(b) ? a : b,
          );

    final adjustedStart = _applySinglePointExtension(
      weights: weights,
      calories: calories,
      currentStart: effectiveStart,
      today: today,
    );

    final maxDays = effectiveEnd.difference(adjustedStart).inDays.toDouble();

    final xInterval = maxDays <= 30
        ? 7.0
        : maxDays <= 180
            ? 30.0
            : 60.0;

    return DashboardRange(
      start: adjustedStart,
      end: effectiveEnd,
      maxDays: maxDays,
      xInterval: xInterval.toInt(),
    );
  }

  static DateTime _applySinglePointExtension({
    required List<BodyweightEntry> weights,
    required List<({String date, double calories})> calories,
    required DateTime currentStart,
    required DateTime today,
  }) {
    if (weights.length != 1 || calories.length != 1) {
      return currentStart;
    }

    final weightDate = DateTime.parse(weights.first.loggedAt);
    final calorieDate = DateTime.parse(calories.first.date);

    final weightDay = DateTime(weightDate.year, weightDate.month, weightDate.day);
    final calorieDay = DateTime(calorieDate.year, calorieDate.month, calorieDate.day);

    if (weightDay == calorieDay) {
      return weightDay.subtract(const Duration(days: 1));
    }

    return currentStart;
  }
}
