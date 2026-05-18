import 'package:flutter_test/flutter_test.dart';

import 'package:bioloop/core/database/database.dart';
import 'package:bioloop/providers/dashboard_time_range_provider.dart';
import 'package:bioloop/providers/shared_dashboard_range_provider.dart';

void main() {
  group('DashboardRange.compute', () {
    test('single weight + single calorie on same day extends start back 1 day', () {
      final today = DateTime.now();
      final sameDay = DateTime(today.year, today.month, today.day);
      final sameDayStr = sameDay.toIso8601String();

      final weights = [
        BodyweightEntry(id: 1, weightKg: 80.0, loggedAt: sameDayStr),
      ];
      final calories = [
        (date: sameDayStr, calories: 2000.0),
      ];

      final range = DashboardRange.compute(
        timeRange: TimeRange.oneMonth,
        weights: weights,
        calories: calories,
      );

      final expectedStart = sameDay.subtract(const Duration(days: 1));
      expect(range.start.year, expectedStart.year);
      expect(range.start.month, expectedStart.month);
      expect(range.start.day, expectedStart.day);
      expect(range.maxDays, greaterThanOrEqualTo(1.0));
    });

    test('single weight + single calorie on different days does not extend', () {
      final today = DateTime.now();
      final weightDay = DateTime(today.year, today.month, today.day);
      final calorieDay = weightDay.subtract(const Duration(days: 1));

      final weights = [
        BodyweightEntry(
          id: 1,
          weightKg: 80.0,
          loggedAt: weightDay.toIso8601String(),
        ),
      ];
      final calories = [
        (date: calorieDay.toIso8601String(), calories: 2000.0),
      ];

      final range = DashboardRange.compute(
        timeRange: TimeRange.oneMonth,
        weights: weights,
        calories: calories,
      );

      expect(range.start.day, calorieDay.day);
      expect(range.start.month, calorieDay.month);
      expect(range.start.year, calorieDay.year);
    });

    test('multiple entries are unaffected by single-point extension', () {
      final today = DateTime.now();
      final day1 = DateTime(today.year, today.month, today.day - 5);
      final day2 = DateTime(today.year, today.month, today.day - 3);

      final weights = [
        BodyweightEntry(id: 1, weightKg: 80.0, loggedAt: day1.toIso8601String()),
        BodyweightEntry(id: 2, weightKg: 80.5, loggedAt: day2.toIso8601String()),
      ];
      final calories = [
        (date: day1.toIso8601String(), calories: 2000.0),
        (date: day2.toIso8601String(), calories: 2100.0),
      ];

      final range = DashboardRange.compute(
        timeRange: TimeRange.oneMonth,
        weights: weights,
        calories: calories,
      );

      expect(range.start.day, day1.day);
      expect(range.start.month, day1.month);
      expect(range.start.year, day1.year);
    });

    test('empty datasets returns range starting from calculatedStart', () {
      final now = DateTime.now();
      final calculatedStart = now.subtract(const Duration(days: 30));

      final range = DashboardRange.compute(
        timeRange: TimeRange.oneMonth,
        weights: [],
        calories: [],
      );

      expect(range.start.year, calculatedStart.year);
      expect(range.start.month, calculatedStart.month);
      expect(range.start.day, calculatedStart.day);
      expect(range.end.year, now.year);
      expect(range.end.month, now.month);
      expect(range.end.day, now.day);
    });

    test('calorie end date extends to today even if latest entry is in the past', () {
      final today = DateTime.now();
      final yesterday = today.subtract(const Duration(days: 1));
      final twoDaysAgo = today.subtract(const Duration(days: 2));

      final weights = [
        BodyweightEntry(
          id: 1,
          weightKg: 80.0,
          loggedAt: yesterday.toIso8601String(),
        ),
      ];
      final calories = [
        (date: twoDaysAgo.toIso8601String(), calories: 2000.0),
      ];

      final range = DashboardRange.compute(
        timeRange: TimeRange.oneMonth,
        weights: weights,
        calories: calories,
      );

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
      final calories = [
        (date: weekAgo.toIso8601String(), calories: 2000.0),
      ];

      final range = DashboardRange.compute(
        timeRange: TimeRange.oneMonth,
        weights: weights,
        calories: calories,
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
      final calories = [
        (date: twoMonthsAgo.toIso8601String(), calories: 2000.0),
      ];

      final range = DashboardRange.compute(
        timeRange: TimeRange.sixMonths,
        weights: weights,
        calories: calories,
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
      final calories = [
        (date: eightMonthsAgo.toIso8601String(), calories: 2000.0),
      ];

      final range = DashboardRange.compute(
        timeRange: TimeRange.allTime,
        weights: weights,
        calories: calories,
      );

      expect(range.xInterval, 60);
    });
  });
}
