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

    final effectiveStart = earliestWeight != null && earliestWeight.isAfter(calculatedStart)
        ? earliestWeight
        : calculatedStart;

    final effectiveEndCandidates = [latestWeight, today].whereType<DateTime>();
    final effectiveEnd = effectiveEndCandidates.isEmpty
        ? today
        : effectiveEndCandidates.reduce(
            (a, b) => a.isAfter(b) ? a : b,
          );

    final normalizedStart = DateTime(effectiveStart.year, effectiveStart.month, effectiveStart.day);
    final maxDays = effectiveEnd.difference(normalizedStart).inDays.toDouble();

    final xInterval = maxDays <= 30
        ? 7.0
        : maxDays <= 180
            ? 30.0
            : 60.0;

    return DashboardRange(
      start: normalizedStart,
      end: effectiveEnd,
      maxDays: maxDays,
      xInterval: xInterval.toInt(),
    );
  }
}
