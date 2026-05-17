import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;

import 'package:bioloop/core/algorithms/maintenance_calculator.dart';
import 'package:bioloop/core/database/database.dart';
import 'package:bioloop/providers/database_provider.dart';
import 'package:bioloop/providers/maintenance_provider.dart';

void main() {
  group('MaintenanceCalculator.calculate', () {
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
      expect(result.dataPoints, greaterThanOrEqualTo(10));
    });

    test('insufficient data — 5 data points returns null with reason', () {
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
      expect(result.dataPoints, lessThan(10));
    });

    test('10 paired points at threshold produces result', () {
      final now = DateTime.now();
      final foodEntries = <FoodEntry>[];
      final weightEntries = <BodyweightEntry>[];

      double weight = 80.0;
      for (int i = 0; i < 30; i++) {
        final day = now.subtract(Duration(days: 29 - i));
        weight -= 0.05;
        weightEntries.add(makeWeight(id: i, weightKg: weight, date: day));
      }
      for (int i = 0; i < 12; i++) {
        final day = now.subtract(Duration(days: 29 - i));
        final cals = 1200 + (i % 5) * 200.0;
        foodEntries.add(makeFood(id: i, calories: cals, date: day));
      }

      final result = MaintenanceCalculator.calculate(
        foodEntries: foodEntries,
        weightEntries: weightEntries,
        now: now,
      );

      expect(result, isNotNull);
      expect(result!.failureReason, isNull);
    });

    test('empty input returns null with noWeights reason', () {
      final result = MaintenanceCalculator.calculate(
        foodEntries: [],
        weightEntries: [],
      );

      expect(result, isNotNull);
      expect(result!.failureReason, MaintenanceFailureReason.noWeights);
    });

    test('no weight variance — all weights identical returns null with reason', () {
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
      expect(result!.failureReason, MaintenanceFailureReason.noWeightVariance);
    });

    test('constant calories — no variance returns null with reason', () {
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
      expect(result!.failureReason, MaintenanceFailureReason.noCalorieVariance);
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
      expect(result.dataPoints, greaterThanOrEqualTo(10));
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
      expect(result!.maintenanceCalories,
          closeTo(trueMaintenance, trueMaintenance * 0.10));
      expect(result.dataPoints, greaterThanOrEqualTo(10));
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
      expect(result.dataPoints, greaterThanOrEqualTo(10));
    });

    test('single weight entry — all 30 days use oldest weight', () {
      final now = DateTime.now();
      final foodEntries = <FoodEntry>[];
      final weightEntries = <BodyweightEntry>[];

      // 30 days of food with calorie variance
      for (int i = 0; i < 30; i++) {
        final day = now.subtract(Duration(days: 29 - i));
        final cals = 2000.0 + (i % 5) * 200;
        foodEntries.add(makeFood(id: i, calories: cals, date: day));
      }

      // Single weight on last day (onboarding today)
      weightEntries.add(makeWeight(id: 0, weightKg: 80.0, date: now));

      final result = MaintenanceCalculator.calculate(
        foodEntries: foodEntries,
        weightEntries: weightEntries,
        now: now,
      );

      // Should have 30 weight points (all forward-filled with 80.0)
      // But no weight variance → slope = 0 → returns null with noWeightVariance
      expect(result, isNotNull);
      expect(result!.failureReason, MaintenanceFailureReason.noWeightVariance);
    });

    test('delete oldest weight — assumption shifts to new oldest', () {
      final now = DateTime.now();
      final rng = Random(42);
      final foodEntries = <FoodEntry>[];
      final weightEntries = <BodyweightEntry>[];

      // 30 days of food with variance
      final pattern = [-500.0, -250.0, 0.0, 250.0, 500.0];
      for (int i = 0; i < 30; i++) {
        final day = now.subtract(Duration(days: 29 - i));
        final cals = 2500.0 + pattern[i % 5];
        foodEntries.add(makeFood(id: i, calories: cals, date: day));
      }

      // Multiple weights with variance (not just 2)
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

      // Verify initial result with all weights
      expect(result1, isNotNull);

      // Now remove first 5 weights (simulate deletion of oldest weights)
      for (int i = 0; i < 5; i++) {
        if (weightEntries.isNotEmpty) weightEntries.removeAt(0);
      }

      final result2 = MaintenanceCalculator.calculate(
        foodEntries: foodEntries,
        weightEntries: weightEntries,
        now: now,
      );

      // Should still produce a result (assumption shifts to new oldest)
      expect(result2, isNotNull);
    });

    test('weight entries start mid-window — prior dates use oldest weight', () {
      final now = DateTime.now();
      final rng = Random(42);
      final foodEntries = <FoodEntry>[];
      final weightEntries = <BodyweightEntry>[];

      // 30 days of food with variance
      final pattern = [-500.0, -250.0, 0.0, 250.0, 500.0];
      for (int i = 0; i < 30; i++) {
        final day = now.subtract(Duration(days: 29 - i));
        final cals = 2500.0 + pattern[i % 5];
        foodEntries.add(makeFood(id: i, calories: cals, date: day));
      }

      // Weights only on days 10-30 (user started logging late)
      // But we need enough variance, so add noise
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

      // Should have 30 weight points (days 1-9 use day 10's weight via forward-fill)
      expect(result, isNotNull);
      expect(result!.dataPoints, greaterThanOrEqualTo(14));
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

      // Add 30 days of food with varying calories (yesterday and prior)
      for (int i = 0; i < 30; i++) {
        final day = today.subtract(Duration(days: 30 - i));
        final cals = 2500.0 + pattern[i % 5];  // Varying calories
        foodEntries.add(makeFood(id: i, calories: cals, date: day));
      }

      // Add today's food with VERY DIFFERENT calories (should be excluded)
      foodEntries.add(makeFood(
        id: 30,
        calories: 5000.0,
        date: today,
      ));

      // Add weights for all days with small variance (needed for regression)
      for (int i = 0; i < 31; i++) {
        final day = today.subtract(Duration(days: 30 - i));
        // Small weight changes correlated with calorie pattern
        final weight = 80.0 + (pattern[i % 5] / 3500.0) * (i / 5);
        weightEntries.add(makeWeight(id: i, weightKg: weight, date: day));
      }

      // Call without `now` parameter — should default to excluding today
      final result = MaintenanceCalculator.calculate(
        foodEntries: foodEntries,
        weightEntries: weightEntries,
      );

      // Should produce valid result (not skewed by today's 5000 cal outlier)
      expect(result, isNotNull);
      expect(result!.failureReason, isNull);
      // If today was included, maintenance would be inflated
      // With today excluded, should be close to 2500 (average of pattern)
      expect(result.maintenanceCalories, closeTo(2500.0, 250));
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
      expect(result.dataPoints, greaterThanOrEqualTo(10));
      expect(result.confidenceInterval, greaterThan(0));
    });
  });
}
