import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;

import 'package:bioloop/core/algorithms/maintenance_calculator.dart';
import 'package:bioloop/core/database/database.dart';
import 'package:bioloop/providers/database_provider.dart';
import 'package:bioloop/providers/maintenance_provider.dart';

void main() {
  FoodEntry makeFood({
    required int id,
    required double calories,
    required DateTime date,
  }) {
    final dateStr =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    return FoodEntry(
      id: id,
      name: 'Food $id',
      calories: calories,
      proteinGrams: 0,
      carbsGrams: 0,
      fatGrams: 0,
      servings: 1,
      servingLabel: 'serving',
      barcode: null,
      foodId: null,
      recipeId: null,
      mealType: 'snack',
      loggedAt: '${dateStr}T12:00:00',
    );
  }

  BodyweightEntry makeWeight({
    required int id,
    required double weightKg,
    required DateTime date,
  }) {
    final dateStr =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    return BodyweightEntry(id: id, weightKg: weightKg, loggedAt: dateStr);
  }

  group('MaintenanceCalculator.calculate', () {

    test('known maintenance = 2500 kcal — within 5%', () {
      final rng = Random(42);
      final now = DateTime.now();
      const trueMaintenance = 2500.0;
      const startWeight = 80.0;
      final pattern = [-500.0, -250.0, 0.0, 250.0, 500.0];

      final foodEntries = <FoodEntry>[];
      final weightEntries = <BodyweightEntry>[];
      double cumulativeKg = 0;

      for (int i = 0; i < 60; i++) {
        final day = now.subtract(Duration(days: 59 - i));
        final cals = trueMaintenance + pattern[i % 5];

        foodEntries.add(makeFood(id: i, calories: cals, date: day));

        final dailyChangeLbs = (cals - trueMaintenance) / 3500.0;
        final dailyChangeKg = dailyChangeLbs / 2.20462;
        cumulativeKg += dailyChangeKg;

        final noisyWeight =
            startWeight + cumulativeKg + (rng.nextDouble() - 0.5) * 0.1;
        weightEntries.add(makeWeight(id: i, weightKg: noisyWeight, date: day));
      }

      final result = MaintenanceCalculator.calculate(
        foodEntries: foodEntries,
        weightEntries: weightEntries,
        now: now,
      );

      expect(result, isNotNull);
      expect(result!.maintenanceCalories,
          closeTo(trueMaintenance, trueMaintenance * 0.05));
      expect(result.dataPoints, greaterThanOrEqualTo(5));
    });

    test('insufficient data — 3 weights, 5 day span — returns failure', () {
      final now = DateTime.now();
      final foodEntries = <FoodEntry>[];
      final weightEntries = <BodyweightEntry>[];

      for (int i = 0; i < 5; i++) {
        final day = now.subtract(Duration(days: 4 - i));
        foodEntries.add(makeFood(id: i, calories: 2500, date: day));
        weightEntries.add(makeWeight(id: i, weightKg: 80, date: day));
      }

      final result = MaintenanceCalculator.calculate(
        foodEntries: foodEntries,
        weightEntries: weightEntries,
        now: now,
      );

      expect(result, isNotNull);
      expect(result!.failureReason, MaintenanceFailureReason.insufficientPairedData);
      expect(result.dataPoints, 5);
    });

    test('1 paired day returns insufficientPairedData', () {
      final now = DateTime.now();
      final yesterday = now.subtract(const Duration(days: 1));

      final foodEntries = [
        makeFood(id: 0, calories: 2500, date: yesterday),
      ];
      final weightEntries = [
        makeWeight(id: 0, weightKg: 80, date: yesterday),
      ];

      final result = MaintenanceCalculator.calculate(
        foodEntries: foodEntries,
        weightEntries: weightEntries,
        now: now,
      );

      expect(result, isNotNull);
      expect(result!.failureReason, MaintenanceFailureReason.insufficientPairedData);
      expect(result.dataPoints, 1);
    });

    test('5 weights over 5 days — insufficient span', () {
      final now = DateTime.now();
      final foodEntries = <FoodEntry>[];
      final weightEntries = <BodyweightEntry>[];

      for (int i = 0; i < 5; i++) {
        final day = now.subtract(Duration(days: 5 - i));
        foodEntries.add(makeFood(id: i, calories: 2500, date: day));
        weightEntries.add(makeWeight(id: i, weightKg: 80, date: day));
      }

      final result = MaintenanceCalculator.calculate(
        foodEntries: foodEntries,
        weightEntries: weightEntries,
        now: now,
      );

      expect(result, isNotNull);
      expect(result!.failureReason, MaintenanceFailureReason.insufficientPairedData);
    });

    test('empty input returns null with noWeights reason', () {
      final result = MaintenanceCalculator.calculate(
        foodEntries: [],
        weightEntries: [],
      );

      expect(result, isNotNull);
      expect(result!.failureReason, MaintenanceFailureReason.noWeights);
    });

    test('no weight variance — all weights identical returns average calories as maintenance', () {
      final now = DateTime.now();
      final foodEntries = <FoodEntry>[];
      final weightEntries = <BodyweightEntry>[];

      for (int i = 0; i < 30; i++) {
        final day = now.subtract(Duration(days: 29 - i));
        final cals = 2000.0 + (i % 5) * 200;
        foodEntries.add(makeFood(id: i, calories: cals, date: day));
        weightEntries.add(makeWeight(id: i, weightKg: 80.0, date: day));
      }

      final result = MaintenanceCalculator.calculate(
        foodEntries: foodEntries,
        weightEntries: weightEntries,
        now: now,
      );

      expect(result, isNotNull);
      expect(result!.failureReason, isNull);
      expect(result.maintenanceCalories, closeTo(2400, 100));
      expect(result.confidenceInterval, equals(double.infinity));
    });

    test('constant calories — no variance returns average calories as maintenance', () {
      final now = DateTime.now();
      final rng = Random(42);
      final foodEntries = <FoodEntry>[];
      final weightEntries = <BodyweightEntry>[];

      double cumulativeKg = 0;
      for (int i = 0; i < 30; i++) {
        final day = now.subtract(Duration(days: 29 - i));
        foodEntries.add(makeFood(id: i, calories: 2500, date: day));

        cumulativeKg += (rng.nextDouble() - 0.5) * 0.05;
        final noisyWeight = 80.0 + cumulativeKg + (rng.nextDouble() - 0.5) * 0.1;
        weightEntries.add(makeWeight(id: i, weightKg: noisyWeight, date: day));
      }

      final result = MaintenanceCalculator.calculate(
        foodEntries: foodEntries,
        weightEntries: weightEntries,
        now: now,
      );

      expect(result, isNotNull);
      expect(result!.failureReason, isNull);
      expect(result.maintenanceCalories, closeTo(2500, 100));
    });

    test('extreme outlier — spike smoothed, maintenance within 10%', () {
      final now = DateTime.now();
      const trueMaintenance = 2500.0;
      const startWeight = 80.0;
      final pattern = [-500.0, -250.0, 0.0, 250.0, 500.0];

      final foodEntries = <FoodEntry>[];
      final weightEntries = <BodyweightEntry>[];
      double cumulativeKg = 0;

      for (int i = 0; i < 60; i++) {
        final day = now.subtract(Duration(days: 59 - i));
        final cals = trueMaintenance + pattern[i % 5];

        foodEntries.add(makeFood(id: i, calories: cals, date: day));

        final dailyChangeLbs = (cals - trueMaintenance) / 3500.0;
        final dailyChangeKg = dailyChangeLbs / 2.20462;
        cumulativeKg += dailyChangeKg;

        double weight = startWeight + cumulativeKg;
        if (i == 30) {
          weight = startWeight + cumulativeKg + 5.0;
        }

        weightEntries.add(makeWeight(id: i, weightKg: weight, date: day));
      }

      final result = MaintenanceCalculator.calculate(
        foodEntries: foodEntries,
        weightEntries: weightEntries,
        now: now,
      );

      expect(result, isNotNull);
      expect(result!.maintenanceCalories,
          closeTo(trueMaintenance, trueMaintenance * 0.10));
      expect(result.dataPoints, greaterThanOrEqualTo(5));
    });

    test('confidence interval grows with data variance', () {
      final now = DateTime.now();
      const trueMaintenance = 2500.0;
      const startWeight = 80.0;
      final pattern = [-500.0, -250.0, 0.0, 250.0, 500.0];

      MaintenanceResult runWithNoise(double noiseLevel) {
        final rng = Random(42);
        final foodEntries = <FoodEntry>[];
        final weightEntries = <BodyweightEntry>[];
        double cumulativeKg = 0;

        for (int i = 0; i < 60; i++) {
          final day = now.subtract(Duration(days: 59 - i));
          final cals = trueMaintenance + pattern[i % 5];

          foodEntries.add(makeFood(id: i, calories: cals, date: day));

          final dailyChangeLbs = (cals - trueMaintenance) / 3500.0;
          final dailyChangeKg = dailyChangeLbs / 2.20462;
          cumulativeKg += dailyChangeKg;

          final noisyWeight = startWeight +
              cumulativeKg +
              (rng.nextDouble() - 0.5) * noiseLevel;
          weightEntries.add(
              makeWeight(id: i, weightKg: noisyWeight, date: day));
        }

        return MaintenanceCalculator.calculate(
          foodEntries: foodEntries,
          weightEntries: weightEntries,
          now: now,
        )!;
      }

      final lowNoise = runWithNoise(0.1);
      final highNoise = runWithNoise(2.0);

      expect(highNoise.confidenceInterval,
          greaterThan(lowNoise.confidenceInterval));
    });

    test('sparse logging — Mon+Fri only, still produces result', () {
      final now = DateTime(2024, 1, 28);
      const trueMaintenance = 2500.0;
      const startWeight = 80.0;
      final pattern = [-500.0, -250.0, 0.0, 250.0, 500.0];
      final rng = Random(42);

      final foodEntries = <FoodEntry>[];
      final weightEntries = <BodyweightEntry>[];
      double cumulativeKg = 0;

      for (int i = 0; i < 28; i++) {
        final day = now.subtract(Duration(days: 27 - i));
        final cals = trueMaintenance + pattern[i % 5];

        foodEntries.add(makeFood(id: i, calories: cals, date: day));

        final dailyChangeLbs = (cals - trueMaintenance) / 3500.0;
        final dailyChangeKg = dailyChangeLbs / 2.20462;
        cumulativeKg += dailyChangeKg;

        if (day.weekday == DateTime.monday ||
            day.weekday == DateTime.friday) {
          final noisyWeight = startWeight +
              cumulativeKg +
              (rng.nextDouble() - 0.5) * 0.1;
          weightEntries.add(
              makeWeight(id: i, weightKg: noisyWeight, date: day));
        }
      }

      final result = MaintenanceCalculator.calculate(
        foodEntries: foodEntries,
        weightEntries: weightEntries,
        now: now,
      );

      expect(result, isNotNull);
      expect(result!.failureReason, isNull);
      expect(result.maintenanceCalories,
          closeTo(trueMaintenance, trueMaintenance * 0.10));
      expect(result.dataPoints, greaterThanOrEqualTo(5));
    });

    test('single gap — one missing day does not break result', () {
      final now = DateTime.now();
      const trueMaintenance = 2500.0;
      const startWeight = 80.0;
      final pattern = [-500.0, -250.0, 0.0, 250.0, 500.0];
      final rng = Random(42);

      final foodEntries = <FoodEntry>[];
      final weightEntries = <BodyweightEntry>[];
      double cumulativeKg = 0;

      for (int i = 0; i < 30; i++) {
        final day = now.subtract(Duration(days: 29 - i));
        final cals = trueMaintenance + pattern[i % 5];

        foodEntries.add(makeFood(id: i, calories: cals, date: day));

        final dailyChangeLbs = (cals - trueMaintenance) / 3500.0;
        final dailyChangeKg = dailyChangeLbs / 2.20462;
        cumulativeKg += dailyChangeKg;

        if (i != 10) {
          final noisyWeight = startWeight +
              cumulativeKg +
              (rng.nextDouble() - 0.5) * 0.1;
          weightEntries.add(
              makeWeight(id: i, weightKg: noisyWeight, date: day));
        }
      }

      final result = MaintenanceCalculator.calculate(
        foodEntries: foodEntries,
        weightEntries: weightEntries,
        now: now,
      );

      expect(result, isNotNull);
      expect(result!.maintenanceCalories,
          closeTo(trueMaintenance, trueMaintenance * 0.05));
      expect(result.dataPoints, greaterThanOrEqualTo(5));
    });

    test('single weight entry — insufficient data for trend', () {
      final now = DateTime.now();
      final foodEntries = <FoodEntry>[];
      final weightEntries = <BodyweightEntry>[];

      for (int i = 0; i < 30; i++) {
        final day = now.subtract(Duration(days: 29 - i));
        final cals = 2000.0 + (i % 5) * 200;
        foodEntries.add(makeFood(id: i, calories: cals, date: day));
      }

      weightEntries.add(makeWeight(id: 0, weightKg: 80.0, date: now));

      final result = MaintenanceCalculator.calculate(
        foodEntries: foodEntries,
        weightEntries: weightEntries,
        now: now,
      );

      expect(result, isNotNull);
      expect(result!.failureReason, MaintenanceFailureReason.insufficientPairedData);
    });

    test('delete oldest weight — assumption shifts to new oldest', () {
      final now = DateTime.now();
      final rng = Random(42);
      final foodEntries = <FoodEntry>[];
      final weightEntries = <BodyweightEntry>[];

      final pattern = [-500.0, -250.0, 0.0, 250.0, 500.0];
      for (int i = 0; i < 30; i++) {
        final day = now.subtract(Duration(days: 29 - i));
        final cals = 2500.0 + pattern[i % 5];
        foodEntries.add(makeFood(id: i, calories: cals, date: day));
      }

      double cumulativeKg = 0;
      for (int i = 0; i < 30; i++) {
        final day = now.subtract(Duration(days: 29 - i));
        final cals = 2500.0 + pattern[i % 5];
        final dailyChangeLbs = (cals - 2500.0) / 3500.0;
        final dailyChangeKg = dailyChangeLbs / 2.20462;
        cumulativeKg += dailyChangeKg;
        final noisyWeight = 80.0 + cumulativeKg + (rng.nextDouble() - 0.5) * 0.1;
        weightEntries.add(makeWeight(id: i, weightKg: noisyWeight, date: day));
      }

      final result1 = MaintenanceCalculator.calculate(
        foodEntries: foodEntries,
        weightEntries: weightEntries,
        now: now,
      );

      expect(result1, isNotNull);

      for (int i = 0; i < 5; i++) {
        if (weightEntries.isNotEmpty) weightEntries.removeAt(0);
      }

      final result2 = MaintenanceCalculator.calculate(
        foodEntries: foodEntries,
        weightEntries: weightEntries,
        now: now,
      );

      expect(result2, isNotNull);
    });

    test('weight entries start mid-window — still produces result', () {
      final now = DateTime.now();
      final rng = Random(42);
      final foodEntries = <FoodEntry>[];
      final weightEntries = <BodyweightEntry>[];

      final pattern = [-500.0, -250.0, 0.0, 250.0, 500.0];
      for (int i = 0; i < 30; i++) {
        final day = now.subtract(Duration(days: 29 - i));
        final cals = 2500.0 + pattern[i % 5];
        foodEntries.add(makeFood(id: i, calories: cals, date: day));
      }

      double cumulativeKg = 0;
      for (int i = 10; i < 30; i++) {
        final day = now.subtract(Duration(days: 29 - i));
        final cals = 2500.0 + pattern[i % 5];
        final dailyChangeLbs = (cals - 2500.0) / 3500.0;
        final dailyChangeKg = dailyChangeLbs / 2.20462;
        cumulativeKg += dailyChangeKg;
        final noisyWeight = 80.0 + cumulativeKg + (rng.nextDouble() - 0.5) * 0.1;
        weightEntries.add(makeWeight(id: i, weightKg: noisyWeight, date: day));
      }

      final result = MaintenanceCalculator.calculate(
        foodEntries: foodEntries,
        weightEntries: weightEntries,
        now: now,
      );

      expect(result, isNotNull);
      expect(result!.dataPoints, greaterThanOrEqualTo(5));
    });

    test('no weight entries — returns null with noWeights reason', () {
      final now = DateTime.now();
      final foodEntries = <FoodEntry>[];
      final weightEntries = <BodyweightEntry>[];

      for (int i = 0; i < 30; i++) {
        final day = now.subtract(Duration(days: 29 - i));
        foodEntries.add(makeFood(id: i, calories: 2500, date: day));
      }

      final result = MaintenanceCalculator.calculate(
        foodEntries: foodEntries,
        weightEntries: weightEntries,
        now: now,
      );

      expect(result, isNotNull);
      expect(result!.failureReason, MaintenanceFailureReason.noWeights);
    });

    test('excludes today from calorie aggregation', () {
      final today = DateTime.now();
      final foodEntries = <FoodEntry>[];
      final weightEntries = <BodyweightEntry>[];
      final pattern = [-500.0, -250.0, 0.0, 250.0, 500.0];

      for (int i = 0; i < 30; i++) {
        final day = today.subtract(Duration(days: 30 - i));
        final cals = 2500.0 + pattern[i % 5];
        foodEntries.add(makeFood(id: i, calories: cals, date: day));
      }

      foodEntries.add(makeFood(
        id: 30,
        calories: 5000.0,
        date: today,
      ));

      for (int i = 0; i < 31; i++) {
        final day = today.subtract(Duration(days: 30 - i));
        final weight = 80.0 + (pattern[i % 5] / 3500.0) * (i / 5);
        weightEntries.add(makeWeight(id: i, weightKg: weight, date: day));
      }

      final result = MaintenanceCalculator.calculate(
        foodEntries: foodEntries,
        weightEntries: weightEntries,
      );

      expect(result, isNotNull);
      expect(result!.failureReason, isNull);
      expect(result.maintenanceCalories, closeTo(2500.0, 250));
    });

    test('stable weight with calorie variance returns average calories as maintenance', () {
      final now = DateTime.now();
      final foodEntries = <FoodEntry>[];
      final weightEntries = <BodyweightEntry>[];

      for (int i = 0; i < 30; i++) {
        final day = now.subtract(Duration(days: 29 - i));
        final cals = 2000.0 + (i % 6) * 200;
        foodEntries.add(makeFood(id: i, calories: cals, date: day));
        weightEntries.add(makeWeight(id: i, weightKg: 80.0, date: day));
      }

      final result = MaintenanceCalculator.calculate(
        foodEntries: foodEntries,
        weightEntries: weightEntries,
        now: now,
      );

      expect(result, isNotNull);
      expect(result!.failureReason, isNull);
      expect(result.maintenanceCalories, closeTo(2500, 100));
      expect(result.confidenceInterval, equals(double.infinity));
      expect(result.dataPoints, greaterThanOrEqualTo(5));
    });

    test('zero slope case has infinite confidence interval', () {
      final now = DateTime.now();
      final foodEntries = <FoodEntry>[];
      final weightEntries = <BodyweightEntry>[];

      for (int i = 0; i < 30; i++) {
        final day = now.subtract(Duration(days: 29 - i));
        final cals = 2000.0 + (i % 5) * 200;
        foodEntries.add(makeFood(id: i, calories: cals, date: day));
        weightEntries.add(makeWeight(id: i, weightKg: 80.0, date: day));
      }

      final result = MaintenanceCalculator.calculate(
        foodEntries: foodEntries,
        weightEntries: weightEntries,
        now: now,
      );

      expect(result, isNotNull);
      expect(result!.failureReason, isNull);
      expect(result.confidenceInterval, equals(double.infinity));
    });

    test('cheat high but track accurately — weekend binge pattern', () {
      final now = DateTime(2026, 5, 17);
      const trueMaintenance = 2500.0;
      const startWeight = 80.0;

      final foodEntries = <FoodEntry>[];
      final weightEntries = <BodyweightEntry>[];
      double cumulativeKg = 0;
      final rng = Random(42);

      for (int i = 0; i < 60; i++) {
        final day = now.subtract(Duration(days: 59 - i));
        final weekday = day.weekday;
        final calorieOffset = weekday <= 5 ? 0.0 : 750.0;
        final cals = trueMaintenance + calorieOffset;

        foodEntries.add(makeFood(id: i, calories: cals, date: day));

        final dailyChangeLbs = (cals - trueMaintenance) / 3500.0;
        final dailyChangeKg = dailyChangeLbs / 2.20462;
        cumulativeKg += dailyChangeKg;

        final noisyWeight =
            startWeight + cumulativeKg + (rng.nextDouble() - 0.5) * 0.2;
        weightEntries.add(makeWeight(id: i, weightKg: noisyWeight, date: day));
      }

      final result = MaintenanceCalculator.calculate(
        foodEntries: foodEntries,
        weightEntries: weightEntries,
        now: now,
      );

      expect(result, isNotNull);
      expect(result!.failureReason, isNull);
      expect(result.maintenanceCalories, closeTo(trueMaintenance, trueMaintenance * 0.10));
      expect(result.dataPoints, greaterThanOrEqualTo(5));
    });

    test('cheat low but track accurately — weekday restriction pattern', () {
      final now = DateTime(2026, 5, 17);
      const trueMaintenance = 2500.0;
      const startWeight = 80.0;
      final rng = Random(42);

      final foodEntries = <FoodEntry>[];
      final weightEntries = <BodyweightEntry>[];
      double cumulativeKg = 0;

      for (int i = 0; i < 60; i++) {
        final day = now.subtract(Duration(days: 59 - i));
        final weekday = day.weekday;
        double cals;
        if (weekday <= 5) {
          cals = trueMaintenance - 500;
        } else {
          cals = trueMaintenance + 1000;
        }

        foodEntries.add(makeFood(id: i, calories: cals, date: day));

        final dailyChangeLbs = (cals - trueMaintenance) / 3500.0;
        final dailyChangeKg = dailyChangeLbs / 2.20462;
        cumulativeKg += dailyChangeKg;

        final noisyWeight =
            startWeight + cumulativeKg + (rng.nextDouble() - 0.5) * 0.2;
        weightEntries.add(makeWeight(id: i, weightKg: noisyWeight, date: day));
      }

      final result = MaintenanceCalculator.calculate(
        foodEntries: foodEntries,
        weightEntries: weightEntries,
        now: now,
      );

      expect(result, isNotNull);
      expect(result!.failureReason, isNull);
      expect(result.maintenanceCalories, closeTo(trueMaintenance, trueMaintenance * 0.15));
      expect(result.dataPoints, greaterThanOrEqualTo(5));
    });

    test('inconsistent food logging — 4-5 days per week', () {
      final now = DateTime(2026, 5, 17);
      const trueMaintenance = 2500.0;
      const startWeight = 80.0;
      final rng = Random(42);

      final foodEntries = <FoodEntry>[];
      final weightEntries = <BodyweightEntry>[];
      double cumulativeKg = 0;
      int foodId = 0;

      for (int i = 0; i < 60; i++) {
        final day = now.subtract(Duration(days: 59 - i));
        final logFood = rng.nextDouble() < 0.6;

        if (logFood) {
          final cals = trueMaintenance + (rng.nextDouble() - 0.5) * 500;
          foodEntries.add(makeFood(id: foodId++, calories: cals, date: day));

          final dailyChangeLbs = (cals - trueMaintenance) / 3500.0;
          final dailyChangeKg = dailyChangeLbs / 2.20462;
          cumulativeKg += dailyChangeKg;
        }

        final noisyWeight =
            startWeight + cumulativeKg + (rng.nextDouble() - 0.5) * 0.1;
        weightEntries.add(makeWeight(id: i, weightKg: noisyWeight, date: day));
      }

      final result = MaintenanceCalculator.calculate(
        foodEntries: foodEntries,
        weightEntries: weightEntries,
        now: now,
      );

      expect(result, isNotNull);
      expect(result!.failureReason, isNull);
      expect(result.maintenanceCalories, closeTo(trueMaintenance, trueMaintenance * 0.10));
      expect(result.dataPoints, greaterThanOrEqualTo(5));
    });

    test('new user with sparse data — 14 days total', () {
      final now = DateTime(2026, 5, 17);
      const trueMaintenance = 2500.0;
      const startWeight = 80.0;
      final rng = Random(42);

      final foodEntries = <FoodEntry>[];
      final weightEntries = <BodyweightEntry>[];
      double cumulativeKg = 0;

      for (int i = 0; i < 14; i++) {
        final day = now.subtract(Duration(days: 13 - i));
        final cals = trueMaintenance + (rng.nextDouble() - 0.5) * 400;
        foodEntries.add(makeFood(id: i, calories: cals, date: day));

        final dailyChangeLbs = (cals - trueMaintenance) / 3500.0;
        final dailyChangeKg = dailyChangeLbs / 2.20462;
        cumulativeKg += dailyChangeKg;

        final noisyWeight =
            startWeight + cumulativeKg + (rng.nextDouble() - 0.5) * 0.1;
        weightEntries.add(makeWeight(id: i, weightKg: noisyWeight, date: day));
      }

      final result = MaintenanceCalculator.calculate(
        foodEntries: foodEntries,
        weightEntries: weightEntries,
        now: now,
      );

      expect(result, isNotNull);
      expect(result!.failureReason, isNull);
      expect(result.maintenanceCalories, closeTo(trueMaintenance, trueMaintenance * 0.20));
      expect(result.dataPoints, greaterThanOrEqualTo(5));
    });

    test('perfect adherence user — same calories daily, stable weight', () {
      final now = DateTime(2026, 5, 17);
      const trueMaintenance = 2500.0;
      const startWeight = 80.0;

      final foodEntries = <FoodEntry>[];
      final weightEntries = <BodyweightEntry>[];

      for (int i = 0; i < 30; i++) {
        final day = now.subtract(Duration(days: 29 - i));
        foodEntries.add(makeFood(id: i, calories: trueMaintenance, date: day));
        weightEntries.add(makeWeight(id: i, weightKg: startWeight, date: day));
      }

      final result = MaintenanceCalculator.calculate(
        foodEntries: foodEntries,
        weightEntries: weightEntries,
        now: now,
      );

      expect(result, isNotNull);
      expect(result!.failureReason, isNull);
      expect(result.maintenanceCalories, closeTo(trueMaintenance, 100));
      expect(result.confidenceInterval, equals(double.infinity));
      expect(result.dataPoints, greaterThanOrEqualTo(5));
    });

    test('long-term user — 180 days of data', () {
      final now = DateTime(2026, 5, 17);
      const trueMaintenance = 2500.0;
      const startWeight = 80.0;
      final rng = Random(42);
      final pattern = [-500.0, -250.0, 0.0, 250.0, 500.0];

      final foodEntries = <FoodEntry>[];
      final weightEntries = <BodyweightEntry>[];
      double cumulativeKg = 0;

      for (int i = 0; i < 180; i++) {
        final day = now.subtract(Duration(days: 179 - i));
        final cals = trueMaintenance + pattern[i % 5];
        foodEntries.add(makeFood(id: i, calories: cals, date: day));

        final dailyChangeLbs = (cals - trueMaintenance) / 3500.0;
        final dailyChangeKg = dailyChangeLbs / 2.20462;
        cumulativeKg += dailyChangeKg;

        final noisyWeight =
            startWeight + cumulativeKg + (rng.nextDouble() - 0.5) * 0.1;
        weightEntries.add(makeWeight(id: i, weightKg: noisyWeight, date: day));
      }

      final stopwatch = Stopwatch()..start();
      final result = MaintenanceCalculator.calculate(
        foodEntries: foodEntries,
        weightEntries: weightEntries,
        now: now,
      );
      stopwatch.stop();

      expect(result, isNotNull);
      expect(result!.failureReason, isNull);
      expect(result.maintenanceCalories, closeTo(trueMaintenance, trueMaintenance * 0.05));
      expect(result.dataPoints, greaterThanOrEqualTo(5));
      expect(stopwatch.elapsedMilliseconds, lessThan(500));
    });

    test('weight loss journey — 90 days, 1 lb/week loss', () {
      final now = DateTime(2026, 5, 17);
      const trueMaintenance = 2500.0;
      const startWeight = 80.0;
      final rng = Random(42);

      final foodEntries = <FoodEntry>[];
      final weightEntries = <BodyweightEntry>[];
      double weightKg = startWeight;

      for (int i = 0; i < 90; i++) {
        final day = now.subtract(Duration(days: 89 - i));
        const dailyDeficitCal = 500.0;
        final cals = trueMaintenance - dailyDeficitCal + (rng.nextDouble() - 0.5) * 200;
        foodEntries.add(makeFood(id: i, calories: cals, date: day));

        final dailyChangeLbs = 1.0 / 7.0;
        final dailyChangeKg = dailyChangeLbs / 2.20462;
        weightKg -= dailyChangeKg;

        final noisyWeight = weightKg + (rng.nextDouble() - 0.5) * 0.2;
        weightEntries.add(makeWeight(id: i, weightKg: noisyWeight, date: day));
      }

      final result = MaintenanceCalculator.calculate(
        foodEntries: foodEntries,
        weightEntries: weightEntries,
        now: now,
      );

      expect(result, isNotNull);
      expect(result!.failureReason, isNull);
      expect(result.maintenanceCalories, closeTo(trueMaintenance, trueMaintenance * 0.15));
      expect(result.dataPoints, greaterThanOrEqualTo(5));
    });

    test('weight gain journey — 90 days, 1 lb/week gain', () {
      final now = DateTime(2026, 5, 17);
      const trueMaintenance = 2500.0;
      const startWeight = 80.0;
      final rng = Random(42);

      final foodEntries = <FoodEntry>[];
      final weightEntries = <BodyweightEntry>[];
      double weightKg = startWeight;

      for (int i = 0; i < 90; i++) {
        final day = now.subtract(Duration(days: 89 - i));
        const dailySurplusCal = 500.0;
        final cals = trueMaintenance + dailySurplusCal + (rng.nextDouble() - 0.5) * 200;
        foodEntries.add(makeFood(id: i, calories: cals, date: day));

        final dailyChangeLbs = 1.0 / 7.0;
        final dailyChangeKg = dailyChangeLbs / 2.20462;
        weightKg += dailyChangeKg;

        final noisyWeight = weightKg + (rng.nextDouble() - 0.5) * 0.2;
        weightEntries.add(makeWeight(id: i, weightKg: noisyWeight, date: day));
      }

      final result = MaintenanceCalculator.calculate(
        foodEntries: foodEntries,
        weightEntries: weightEntries,
        now: now,
      );

      expect(result, isNotNull);
      expect(result!.failureReason, isNull);
      expect(result.maintenanceCalories, closeTo(trueMaintenance, trueMaintenance * 0.15));
      expect(result.dataPoints, greaterThanOrEqualTo(5));
    });

    test('plateau then change — 30 days stable, 30 days deficit', () {
      final now = DateTime(2026, 5, 17);
      const trueMaintenance = 2500.0;
      const startWeight = 80.0;
      final rng = Random(42);

      final foodEntries = <FoodEntry>[];
      final weightEntries = <BodyweightEntry>[];
      double weightKg = startWeight;

      for (int i = 0; i < 60; i++) {
        final day = now.subtract(Duration(days: 59 - i));
        final cals = i < 30 ? trueMaintenance : (trueMaintenance - 500);
        foodEntries.add(makeFood(id: i, calories: cals, date: day));

        if (i >= 30) {
          weightKg -= 0.03;
        }
        final noisyWeight = weightKg + (rng.nextDouble() - 0.5) * 0.1;
        weightEntries.add(makeWeight(id: i, weightKg: noisyWeight, date: day));
      }

      final result = MaintenanceCalculator.calculate(
        foodEntries: foodEntries,
        weightEntries: weightEntries,
        now: now,
      );

      expect(result, isNotNull);
      expect(result!.failureReason, isNull);
      expect(result.dataPoints, greaterThanOrEqualTo(5));
    });

    test('adaptive thermogenesis — 180 days, shifting maintenance', () {
      final now = DateTime(2026, 5, 17);
      const startWeight = 80.0;
      final rng = Random(42);

      final foodEntries = <FoodEntry>[];
      final weightEntries = <BodyweightEntry>[];
      double weightKg = startWeight;

      for (int i = 0; i < 180; i++) {
        final day = now.subtract(Duration(days: 179 - i));
        double maintenance;
        if (i < 90) {
          maintenance = 2500.0;
        } else {
          maintenance = 2300.0;
        }
        final cals = maintenance + (rng.nextDouble() - 0.5) * 300;
        foodEntries.add(makeFood(id: i, calories: cals, date: day));

        final dailyChangeLbs = (cals - maintenance) / 3500.0;
        final dailyChangeKg = dailyChangeLbs / 2.20462;
        weightKg += dailyChangeKg;

        final noisyWeight = weightKg + (rng.nextDouble() - 0.5) * 0.1;
        weightEntries.add(makeWeight(id: i, weightKg: noisyWeight, date: day));
      }

      final result = MaintenanceCalculator.calculate(
        foodEntries: foodEntries,
        weightEntries: weightEntries,
        now: now,
      );

      expect(result, isNotNull);
      expect(result!.failureReason, isNull);
      expect(result.maintenanceCalories, closeTo(2400, 200));
      expect(result.dataPoints, greaterThanOrEqualTo(5));
    });

    test('high variance weight measurements — ±2 lb scale noise', () {
      final now = DateTime(2026, 5, 17);
      const trueMaintenance = 2500.0;
      const startWeight = 80.0;
      final rng = Random(42);
      final pattern = [-500.0, -250.0, 0.0, 250.0, 500.0];

      final foodEntries = <FoodEntry>[];
      final weightEntries = <BodyweightEntry>[];
      double cumulativeKg = 0;

      for (int i = 0; i < 60; i++) {
        final day = now.subtract(Duration(days: 59 - i));
        final cals = trueMaintenance + pattern[i % 5];
        foodEntries.add(makeFood(id: i, calories: cals, date: day));

        final dailyChangeLbs = (cals - trueMaintenance) / 3500.0;
        final dailyChangeKg = dailyChangeLbs / 2.20462;
        cumulativeKg += dailyChangeKg;

        final noisyWeight =
            startWeight + cumulativeKg + (rng.nextDouble() - 0.5) * 2.0;
        weightEntries.add(makeWeight(id: i, weightKg: noisyWeight, date: day));
      }

      final result = MaintenanceCalculator.calculate(
        foodEntries: foodEntries,
        weightEntries: weightEntries,
        now: now,
      );

      expect(result, isNotNull);
      expect(result!.failureReason, isNull);
      expect(result.maintenanceCalories, closeTo(trueMaintenance, trueMaintenance * 0.15));
      expect(result.confidenceInterval, greaterThan(20));
      expect(result.dataPoints, greaterThanOrEqualTo(5));
    });

    test('vacation gap — 10 day logging gap mid-stream', () {
      final now = DateTime(2026, 5, 17);
      const trueMaintenance = 2500.0;
      const startWeight = 80.0;
      final rng = Random(42);
      final pattern = [-500.0, -250.0, 0.0, 250.0, 500.0];

      final foodEntries = <FoodEntry>[];
      final weightEntries = <BodyweightEntry>[];
      double cumulativeKg = 0;
      int foodId = 0;

      for (int i = 0; i < 60; i++) {
        final day = now.subtract(Duration(days: 59 - i));
        final cals = trueMaintenance + pattern[i % 5];

        if (i < 25 || i >= 35) {
          foodEntries.add(makeFood(id: foodId++, calories: cals, date: day));

          final dailyChangeLbs = (cals - trueMaintenance) / 3500.0;
          final dailyChangeKg = dailyChangeLbs / 2.20462;
          cumulativeKg += dailyChangeKg;
        }

        final noisyWeight =
            startWeight + cumulativeKg + (rng.nextDouble() - 0.5) * 0.1;
        weightEntries.add(makeWeight(id: i, weightKg: noisyWeight, date: day));
      }

      final result = MaintenanceCalculator.calculate(
        foodEntries: foodEntries,
        weightEntries: weightEntries,
        now: now,
      );

      expect(result, isNotNull);
      expect(result!.failureReason, isNull);
      expect(result.maintenanceCalories, closeTo(trueMaintenance, trueMaintenance * 0.10));
      expect(result.dataPoints, greaterThanOrEqualTo(5));
    });

    test('reverse diet pattern — gradual calorie increase, stable weight', () {
      final now = DateTime(2026, 5, 17);
      const startWeight = 80.0;
      final rng = Random(42);

      final foodEntries = <FoodEntry>[];
      final weightEntries = <BodyweightEntry>[];

      for (int i = 0; i < 90; i++) {
        final day = now.subtract(Duration(days: 89 - i));
        final baseCalories = 2000.0 + (i / 90.0) * 1000.0;
        final cals = baseCalories + (rng.nextDouble() - 0.5) * 200;
        foodEntries.add(makeFood(id: i, calories: cals, date: day));

        final noisyWeight = startWeight + (rng.nextDouble() - 0.5) * 0.1;
        weightEntries.add(makeWeight(id: i, weightKg: noisyWeight, date: day));
      }

      final result = MaintenanceCalculator.calculate(
        foodEntries: foodEntries,
        weightEntries: weightEntries,
        now: now,
      );

      expect(result, isNotNull);
      expect(result!.failureReason, isNull);
      expect(result.maintenanceCalories, closeTo(2500, 500));
      expect(result.dataPoints, greaterThanOrEqualTo(5));
    });

    test('multi-year user — 2 years of data, performance test', () {
      final now = DateTime(2026, 5, 17);
      const trueMaintenance = 2500.0;
      const startWeight = 80.0;
      final rng = Random(42);
      final pattern = [-500.0, -250.0, 0.0, 250.0, 500.0];

      final foodEntries = <FoodEntry>[];
      final weightEntries = <BodyweightEntry>[];
      double cumulativeKg = 0;

      for (int i = 0; i < 730; i++) {
        final day = now.subtract(Duration(days: 729 - i));
        final cals = trueMaintenance + pattern[i % 5];
        foodEntries.add(makeFood(id: i, calories: cals, date: day));

        final dailyChangeLbs = (cals - trueMaintenance) / 3500.0;
        final dailyChangeKg = dailyChangeLbs / 2.20462;
        cumulativeKg += dailyChangeKg;

        final noisyWeight =
            startWeight + cumulativeKg + (rng.nextDouble() - 0.5) * 0.1;
        weightEntries.add(makeWeight(id: i, weightKg: noisyWeight, date: day));
      }

      final stopwatch = Stopwatch()..start();
      final result = MaintenanceCalculator.calculate(
        foodEntries: foodEntries,
        weightEntries: weightEntries,
        now: now,
      );
      stopwatch.stop();

      expect(result, isNotNull);
      expect(result!.failureReason, isNull);
      expect(result.maintenanceCalories, closeTo(trueMaintenance, trueMaintenance * 0.05));
      expect(result.dataPoints, greaterThanOrEqualTo(5));
      expect(stopwatch.elapsedMilliseconds, lessThan(2000));
    });

    test('ISSUE.md real-world data — 17 days cutting at ~2569 kcal, weight trending down', () {
      // User: 6'4", ~190lb, male, 32 y/o, lifts 4x/week
      // 17 days of real data — weight clearly trending down from 189.1 to 186.8
      // Average calories ~2569, so maintenance MUST be above 2569
      final now = DateTime(2026, 6, 5);

      final foodEntries = [
        makeFood(id: 0, calories: 2467, date: DateTime(2026, 5, 19)),
        makeFood(id: 1, calories: 2518, date: DateTime(2026, 5, 20)),
        makeFood(id: 2, calories: 2463, date: DateTime(2026, 5, 21)),
        makeFood(id: 3, calories: 2504, date: DateTime(2026, 5, 22)),
        makeFood(id: 4, calories: 2481, date: DateTime(2026, 5, 23)),
        makeFood(id: 5, calories: 2475, date: DateTime(2026, 5, 24)),
        makeFood(id: 6, calories: 2439, date: DateTime(2026, 5, 25)),
        makeFood(id: 7, calories: 2478, date: DateTime(2026, 5, 26)),
        makeFood(id: 8, calories: 2481, date: DateTime(2026, 5, 27)),
        makeFood(id: 9, calories: 2609, date: DateTime(2026, 5, 28)),
        makeFood(id: 10, calories: 2443, date: DateTime(2026, 5, 29)),
        makeFood(id: 11, calories: 2290, date: DateTime(2026, 5, 30)),
        makeFood(id: 12, calories: 2345, date: DateTime(2026, 5, 31)),
        makeFood(id: 13, calories: 2717, date: DateTime(2026, 6, 1)),
        makeFood(id: 14, calories: 2490, date: DateTime(2026, 6, 2)),
        makeFood(id: 15, calories: 2389, date: DateTime(2026, 6, 3)),
        makeFood(id: 16, calories: 4087, date: DateTime(2026, 6, 4)),
      ];

      // Weights in kg (lbs / 2.20462)
      final weightEntries = [
        makeWeight(id: 0, weightKg: 189.1 / 2.20462, date: DateTime(2026, 5, 19)),
        makeWeight(id: 1, weightKg: 189.1 / 2.20462, date: DateTime(2026, 5, 20)),
        makeWeight(id: 2, weightKg: 189.1 / 2.20462, date: DateTime(2026, 5, 21)),
        makeWeight(id: 3, weightKg: 190.1 / 2.20462, date: DateTime(2026, 5, 22)),
        makeWeight(id: 4, weightKg: 190.1 / 2.20462, date: DateTime(2026, 5, 23)),
        makeWeight(id: 5, weightKg: 189.1 / 2.20462, date: DateTime(2026, 5, 24)),
        makeWeight(id: 6, weightKg: 187.6 / 2.20462, date: DateTime(2026, 5, 25)),
        makeWeight(id: 7, weightKg: 187.6 / 2.20462, date: DateTime(2026, 5, 26)),
        makeWeight(id: 8, weightKg: 188.3 / 2.20462, date: DateTime(2026, 5, 27)),
        makeWeight(id: 9, weightKg: 188.3 / 2.20462, date: DateTime(2026, 5, 28)),
        makeWeight(id: 10, weightKg: 188.3 / 2.20462, date: DateTime(2026, 5, 29)),
        makeWeight(id: 11, weightKg: 188.3 / 2.20462, date: DateTime(2026, 5, 30)),
        makeWeight(id: 12, weightKg: 186.8 / 2.20462, date: DateTime(2026, 5, 31)),
        makeWeight(id: 13, weightKg: 186.8 / 2.20462, date: DateTime(2026, 6, 1)),
        makeWeight(id: 14, weightKg: 185.3 / 2.20462, date: DateTime(2026, 6, 2)),
        makeWeight(id: 15, weightKg: 185.3 / 2.20462, date: DateTime(2026, 6, 3)),
        makeWeight(id: 16, weightKg: 186.8 / 2.20462, date: DateTime(2026, 6, 4)),
      ];

      final result = MaintenanceCalculator.calculate(
        foodEntries: foodEntries,
        weightEntries: weightEntries,
        now: now,
      );

      expect(result, isNotNull);
      expect(result!.failureReason, isNull);
      // Weight loss of ~2.3 lb over 16 days at ~2569 avg cal means maintenance > 2569
      // Expected: ~3000-3100 kcal
      expect(result.maintenanceCalories, greaterThan(2700));
      expect(result.maintenanceCalories, lessThan(3500));
      expect(result.dataPoints, 17);
    });
  });

  group('maintenanceProvider', () {
    test('insert entries via DAO, provider emits valid MaintenanceResult',
        () async {
      final db = AppDatabase.createInMemory();
      addTearDown(() => db.close());

      final now = DateTime.now().subtract(const Duration(days: 1));
      final pattern = [-500.0, -250.0, 0.0, 250.0, 500.0];

      double cumulativeKg = 0;
      for (int i = 0; i < 60; i++) {
        final day = now.subtract(Duration(days: 59 - i));
        final dateStr =
            '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
        final cals = 2500.0 + pattern[i % 5];

        await db.insertEntry(FoodEntriesCompanion(
          name: Value('Food $i'),
          calories: Value(cals),
          proteinGrams: const Value(0),
          carbsGrams: const Value(0),
          fatGrams: const Value(0),
          servings: const Value(1),
          servingLabel: const Value('serving'),
          mealType: const Value('snack'),
          loggedAt: Value('${dateStr}T12:00:00'),
        ));

        final dailyChangeLbs = (cals - 2500.0) / 3500.0;
        final dailyChangeKg = dailyChangeLbs / 2.20462;
        cumulativeKg += dailyChangeKg;

        await db.insertWeight(BodyweightEntriesCompanion.insert(
          weightKg: 80.0 + cumulativeKg,
          loggedAt: dateStr,
        ));
      }

      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
        ],
      );
      addTearDown(() => container.dispose());

      final result = await container.read(maintenanceProvider.future);
      expect(result, isNotNull);
      expect(result!.maintenanceCalories, closeTo(2500, 125));
      expect(result.dataPoints, greaterThanOrEqualTo(5));
      expect(result.confidenceInterval, greaterThan(0));
    });
  });

  group('Energy Balance Model', () {
    test('weight loss scenario — maintenance above average intake', () {
      final now = DateTime(2026, 5, 21);
      final foodEntries = <FoodEntry>[];
      final weightEntries = <BodyweightEntry>[];

      for (int i = 0; i < 11; i++) {
        final day = DateTime(2026, 5, 10).add(Duration(days: i));
        foodEntries.add(makeFood(id: i, calories: 2500, date: day));
      }

      for (int i = 0; i < 11; i++) {
        final day = DateTime(2026, 5, 10).add(Duration(days: i));
        final weight = 80.0 - (i * 0.1);
        weightEntries.add(makeWeight(id: i, weightKg: weight, date: day));
      }

      final result = MaintenanceCalculator.calculate(
        foodEntries: foodEntries,
        weightEntries: weightEntries,
        now: now,
      );

      expect(result, isNotNull);
      expect(result!.failureReason, isNull);
      expect(result.maintenanceCalories, greaterThan(2900));
      expect(result.maintenanceCalories, lessThan(3500));
    });

    test('weight gain scenario — maintenance below average intake', () {
      final now = DateTime(2026, 5, 21);
      final foodEntries = <FoodEntry>[];
      final weightEntries = <BodyweightEntry>[];

      for (int i = 0; i < 11; i++) {
        final day = DateTime(2026, 5, 10).add(Duration(days: i));
        foodEntries.add(makeFood(id: i, calories: 2800, date: day));
      }

      for (int i = 0; i < 11; i++) {
        final day = DateTime(2026, 5, 10).add(Duration(days: i));
        final weight = 80.0 + (i * 0.1);
        weightEntries.add(makeWeight(id: i, weightKg: weight, date: day));
      }

      final result = MaintenanceCalculator.calculate(
        foodEntries: foodEntries,
        weightEntries: weightEntries,
        now: now,
      );

      expect(result, isNotNull);
      expect(result!.failureReason, isNull);
      expect(result.maintenanceCalories, greaterThan(1800));
      expect(result.maintenanceCalories, lessThan(2400));
    });

    test('stable weight — returns average calories as maintenance', () {
      final now = DateTime(2026, 5, 21);
      final rng = Random(42);
      final foodEntries = <FoodEntry>[];
      final weightEntries = <BodyweightEntry>[];

      for (int i = 0; i < 11; i++) {
        final day = DateTime(2026, 5, 10).add(Duration(days: i));
        final cals = 2500.0 + (rng.nextDouble() - 0.5) * 400;
        foodEntries.add(makeFood(id: i, calories: cals, date: day));
      }

      for (int i = 0; i < 11; i++) {
        final day = DateTime(2026, 5, 10).add(Duration(days: i));
        final weight = 80.0 + (rng.nextDouble() - 0.5) * 0.2;
        weightEntries.add(makeWeight(id: i, weightKg: weight, date: day));
      }

      final result = MaintenanceCalculator.calculate(
        foodEntries: foodEntries,
        weightEntries: weightEntries,
        now: now,
      );

      expect(result, isNotNull);
      expect(result!.failureReason, isNull);
      expect(result.maintenanceCalories, closeTo(2500, 300));
    });

    test('insufficient data — only 2 days returns failure', () {
      final now = DateTime(2026, 5, 20);
      final foodEntries = <FoodEntry>[];
      final weightEntries = <BodyweightEntry>[];

      for (int i = 0; i < 2; i++) {
        final day = DateTime(2026, 5, 19).add(Duration(days: i));
        foodEntries.add(makeFood(id: i, calories: 2500, date: day));
        weightEntries.add(makeWeight(id: i, weightKg: 80.0, date: day));
      }

      final result = MaintenanceCalculator.calculate(
        foodEntries: foodEntries,
        weightEntries: weightEntries,
        now: now,
      );

      expect(result, isNotNull);
      expect(result!.failureReason, MaintenanceFailureReason.insufficientPairedData);
    });

    test('90-day lookback — uses recent data only', () {
      final now = DateTime(2026, 4, 30);
      final foodEntries = <FoodEntry>[];
      final weightEntries = <BodyweightEntry>[];
      double weight = 80.0;

      for (int i = 0; i < 120; i++) {
        final day = DateTime(2026, 1, 1).add(Duration(days: i));
        double cals;
        if (i < 30) {
          cals = 2000.0;
        } else if (i < 90) {
          cals = 2500.0;
        } else {
          cals = 3000.0;
        }
        foodEntries.add(makeFood(id: i, calories: cals, date: day));
        weightEntries.add(makeWeight(id: i, weightKg: weight, date: day));
      }

      final result = MaintenanceCalculator.calculate(
        foodEntries: foodEntries,
        weightEntries: weightEntries,
        lookbackDays: 90,
        now: now,
      );

      expect(result, isNotNull);
      expect(result!.failureReason, isNull);
      expect(result.maintenanceCalories, greaterThan(2600));
      expect(result.maintenanceCalories, lessThan(2900));
    });
  });
}
