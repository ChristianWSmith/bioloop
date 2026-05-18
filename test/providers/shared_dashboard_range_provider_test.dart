import 'package:flutter_test/flutter_test.dart';

import 'package:bioloop/core/database/database.dart';
import 'package:bioloop/providers/dashboard_time_range_provider.dart';
import 'package:bioloop/providers/shared_dashboard_range_provider.dart';

void main() {
  group('DashboardRange.compute', () {
    test('multiple entries use earliest and latest weight dates', () {
      final today = DateTime.now();
      final day1 = DateTime(today.year, today.month, today.day - 5);
      final day2 = DateTime(today.year, today.month, today.day - 3);

      final weights = [
        BodyweightEntry(id: 1, weightKg: 80.0, loggedAt: day1.toIso8601String()),
        BodyweightEntry(id: 2, weightKg: 80.5, loggedAt: day2.toIso8601String()),
      ];

      final range = DashboardRange.compute(
        timeRange: TimeRange.oneMonth,
        weights: weights,
      );

      expect(range.start.year, day1.year);
      expect(range.start.month, day1.month);
      expect(range.start.day, day1.day);
    });

    test('empty datasets returns range starting from calculatedStart', () {
      final now = DateTime.now();
      final calculatedStart = now.subtract(const Duration(days: 30));

      final range = DashboardRange.compute(
        timeRange: TimeRange.oneMonth,
        weights: [],
      );

      expect(range.start.year, calculatedStart.year);
      expect(range.start.month, calculatedStart.month);
      expect(range.start.day, calculatedStart.day);
      expect(range.end.year, now.year);
      expect(range.end.month, now.month);
      expect(range.end.day, now.day);
    });

    test('range uses weight dates when dataset is non-empty', () {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final weekAgo = today.subtract(const Duration(days: 7));

      final weights = [
        BodyweightEntry(id: 1, weightKg: 80.0, loggedAt: weekAgo.toIso8601String()),
        BodyweightEntry(id: 2, weightKg: 80.5, loggedAt: today.toIso8601String()),
      ];

      final range = DashboardRange.compute(
        timeRange: TimeRange.allTime,
        weights: weights,
      );

      expect(range.start.year, weekAgo.year);
      expect(range.start.month, weekAgo.month);
      expect(range.start.day, weekAgo.day);
      expect(range.end.year, today.year);
      expect(range.end.month, today.month);
      expect(range.end.day, today.day);
    });

    test('xInterval is 7 for ranges <= 30 days', () {
      final today = DateTime.now();
      final weekAgo = today.subtract(const Duration(days: 7));

      final weights = [
        BodyweightEntry(
          id: 1,
          weightKg: 80.0,
          loggedAt: weekAgo.toIso8601String(),
        ),
      ];

      final range = DashboardRange.compute(
        timeRange: TimeRange.oneMonth,
        weights: weights,
      );

      expect(range.xInterval, 7);
    });

    test('xInterval is 30 for ranges <= 180 days', () {
      final today = DateTime.now();
      final twoMonthsAgo = today.subtract(const Duration(days: 60));

      final weights = [
        BodyweightEntry(
          id: 1,
          weightKg: 80.0,
          loggedAt: twoMonthsAgo.toIso8601String(),
        ),
      ];

      final range = DashboardRange.compute(
        timeRange: TimeRange.sixMonths,
        weights: weights,
      );

      expect(range.xInterval, 30);
    });

    test('xInterval is 60 for ranges > 180 days', () {
      final today = DateTime.now();
      final eightMonthsAgo = today.subtract(const Duration(days: 240));

      final weights = [
        BodyweightEntry(
          id: 1,
          weightKg: 80.0,
          loggedAt: eightMonthsAgo.toIso8601String(),
        ),
      ];

      final range = DashboardRange.compute(
        timeRange: TimeRange.allTime,
        weights: weights,
      );

      expect(range.xInterval, 60);
    });

    test('range.start is normalized to midnight when weight entries have time components', () {
      final today = DateTime.now();
      final yesterday = today.subtract(const Duration(days: 1));
      final yesterdayWithTime = DateTime(yesterday.year, yesterday.month, yesterday.day, 8, 30, 15);

      final weights = [
        BodyweightEntry(
          id: 1,
          weightKg: 80.0,
          loggedAt: yesterdayWithTime.toIso8601String(),
        ),
        BodyweightEntry(
          id: 2,
          weightKg: 80.5,
          loggedAt: DateTime(today.year, today.month, today.day, 12, 0, 0).toIso8601String(),
        ),
      ];

      final range = DashboardRange.compute(
        timeRange: TimeRange.oneMonth,
        weights: weights,
      );

      expect(range.start.hour, 0);
      expect(range.start.minute, 0);
      expect(range.start.second, 0);
      expect(range.start.millisecond, 0);
    });

    test('weight end date extends to today even if latest entry is in the past', () {
      final today = DateTime.now();
      final yesterday = today.subtract(const Duration(days: 1));

      final weights = [
        BodyweightEntry(
          id: 1,
          weightKg: 80.0,
          loggedAt: yesterday.toIso8601String(),
        ),
      ];

      final range = DashboardRange.compute(
        timeRange: TimeRange.oneMonth,
        weights: weights,
      );

      expect(range.end.year, today.year);
      expect(range.end.month, today.month);
      expect(range.end.day, today.day);
    });
  });
}
