import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;

import 'package:bioloop/core/algorithms/mifflin_st_jeor.dart';
import 'package:bioloop/core/database/database.dart';
import 'package:bioloop/providers/macro_targets_provider.dart';
import 'package:bioloop/providers/database_provider.dart';


void main() {
  group('MacroTargets.compute', () {
    UserGoal goal({
      String goalType = 'cut',
      double? calorieAdjustment = 0,
      double proteinGPerLb = 1.0,
      double fatCaloriePct = 25.0,
      String? sex = 'male',
      double? heightCm = 178,
      String? birthdate = '1996-01-01',
      int activityLevel = 3,
      int onboardingCompleted = 1,
    }) {
      return UserGoal(
        id: 1,
        goalType: goalType,
        calorieAdjustment: calorieAdjustment,
        proteinGPerLb: proteinGPerLb,
        fatCaloriePct: fatCaloriePct,
        sex: sex,
        heightCm: heightCm,
        birthdate: birthdate,
        goalWeightKg: null,
        useImperial: 0,
        activityLevel: activityLevel,
        onboardingCompleted: onboardingCompleted,
        updatedAt: '2026-01-01',
      );
    }

    test('with regression maintenance — 500 deficit, 80kg, 2500 maintenance',
        () {
      final goals = goal(calorieAdjustment: -500);
      final targets = MacroTargets.compute(
        goals: goals,
        weightKg: 80,
        regressionMaintenance: 2500,
      );

      expect(targets.targetCalories, closeTo(2000, 1));
      expect(targets.proteinGrams, closeTo(176, 1));
      expect(targets.fatGrams, closeTo(55.6, 0.1));
      expect(targets.carbsGrams, closeTo(199, 1));
      expect(targets.rateLbsPerWeek, closeTo(-1.0, 0.01));
      expect(targets.maintenanceCalories, closeTo(2500, 1));
      expect(targets.calorieAdjustment, closeTo(-500, 1));
    });

    test('Mifflin-St Jeor fallback (default moderate)', () {
      final goals = goal(onboardingCompleted: 1, calorieAdjustment: 0);
      final targets = MacroTargets.compute(
        goals: goals,
        weightKg: 80,
        regressionMaintenance: null,
      );

      final estimated = estimateMaintenance(
        sex: 'male',
        weightKg: 80,
        heightCm: 178,
        birthdate: '1996-01-01',
      );
      expect(targets.targetCalories, closeTo(estimated, 1));
      expect(targets.maintenanceCalories, closeTo(estimated, 1));
    });

    test('Mifflin-St Jeor fallback (sedentary) — lower than default', () {
      final defaultTargets = MacroTargets.compute(
        goals: goal(onboardingCompleted: 1, calorieAdjustment: 0),
        weightKg: 80,
        regressionMaintenance: null,
      );
      final sedentary = MacroTargets.compute(
        goals: goal(
          onboardingCompleted: 1,
          calorieAdjustment: 0,
          activityLevel: 1,
        ),
        weightKg: 80,
        regressionMaintenance: null,
      );

      expect(sedentary.targetCalories, lessThan(defaultTargets.targetCalories));
    });

    test('Mifflin-St Jeor fallback (extra active) — higher than default', () {
      final defaultTargets = MacroTargets.compute(
        goals: goal(onboardingCompleted: 1, calorieAdjustment: 0),
        weightKg: 80,
        regressionMaintenance: null,
      );
      final extraActive = MacroTargets.compute(
        goals: goal(
          onboardingCompleted: 1,
          calorieAdjustment: 0,
          activityLevel: 5,
        ),
        weightKg: 80,
        regressionMaintenance: null,
      );

      expect(
          extraActive.targetCalories, greaterThan(defaultTargets.targetCalories));
    });

    test('Mifflin-St Jeor female — different BMR formula', () {
      final goals = goal(
        onboardingCompleted: 1,
        calorieAdjustment: 0,
        sex: 'female',
      );
      final targets = MacroTargets.compute(
        goals: goals,
        weightKg: 80,
        regressionMaintenance: null,
      );

      final estimated = estimateMaintenance(
        sex: 'female',
        weightKg: 80,
        heightCm: 178,
        birthdate: '1996-01-01',
      );
      expect(targets.targetCalories, closeTo(estimated, 1));
    });

    test('pre-onboarding safe floor — max(adjustment, 1200)', () {
      final goals = goal(
        onboardingCompleted: 0,
        calorieAdjustment: -500,
      );
      final targets = MacroTargets.compute(
        goals: goals,
        weightKg: null,
        regressionMaintenance: null,
      );

      expect(targets.targetCalories, closeTo(1200, 1));
      expect(targets.maintenanceCalories, isNull);
    });

    test('different bodyweight changes protein and fat, calories unchanged',
        () {
      final targets80 = MacroTargets.compute(
        goals: goal(calorieAdjustment: -500),
        weightKg: 80,
        regressionMaintenance: 2500,
      );
      final targets60 = MacroTargets.compute(
        goals: goal(calorieAdjustment: -500),
        weightKg: 60,
        regressionMaintenance: 2500,
      );

      expect(targets60.targetCalories, closeTo(2000, 1));
      expect(targets60.proteinGrams, lessThan(targets80.proteinGrams));
    });

    test('rate preview works without maintenance', () {
      final targets = MacroTargets.compute(
        goals: goal(calorieAdjustment: -500),
        weightKg: 80,
        regressionMaintenance: null,
      );

      expect(targets.rateLbsPerWeek, closeTo(-1.0, 0.01));
    });

    test('fat pct boundary at 50%', () {
      final goals = goal(
        calorieAdjustment: -500,
        fatCaloriePct: 50,
      );
      final targets = MacroTargets.compute(
        goals: goals,
        weightKg: 80,
        regressionMaintenance: 2500,
      );

      // targetCalories = 2000, fatCal = 2000 * 0.5 = 1000, fatG = 1000/9 = 111.1
      expect(targets.fatGrams, closeTo(111.1, 0.1));
    });

    test('protein boundary at 2.0 g/lb', () {
      final goals1 = goal(calorieAdjustment: -500);
      final targets1 = MacroTargets.compute(
        goals: goals1,
        weightKg: 80,
        regressionMaintenance: 2500,
      );
      final goals2 = goal(calorieAdjustment: -500, proteinGPerLb: 2.0);
      final targets2 = MacroTargets.compute(
        goals: goals2,
        weightKg: 80,
        regressionMaintenance: 2500,
      );

      expect(targets2.proteinGrams, closeTo(targets1.proteinGrams * 2, 0.1));
    });

    test('zero adjustment gives zero rate', () {
      final targets = MacroTargets.compute(
        goals: goal(calorieAdjustment: 0),
        weightKg: 80,
        regressionMaintenance: 2500,
      );

      expect(targets.rateLbsPerWeek, closeTo(0.0, 0.01));
    });

    test('rate preview values across adjustments', () {
      final cut = MacroTargets.compute(
        goals: goal(calorieAdjustment: -500),
        weightKg: 80,
        regressionMaintenance: 2500,
      );
      final bulk = MacroTargets.compute(
        goals: goal(calorieAdjustment: 300),
        weightKg: 80,
        regressionMaintenance: 2500,
      );
      final maintain = MacroTargets.compute(
        goals: goal(calorieAdjustment: 0),
        weightKg: 80,
        regressionMaintenance: 2500,
      );

      expect(cut.rateLbsPerWeek, closeTo(-1.0, 0.01));
      expect(bulk.rateLbsPerWeek, closeTo(0.6, 0.01));
      expect(maintain.rateLbsPerWeek, closeTo(0.0, 0.01));
    });
  });

  group('macroTargetsProvider', () {
    test('reads from DB and computes targets via Mifflin-St Jeor fallback',
        () async {
      final db = AppDatabase.createInMemory();
      addTearDown(() => db.close());

      await db.upsertGoals(UserGoalsCompanion(
        goalType: const Value('cut'),
        calorieAdjustment: const Value(-500),
        proteinGPerLb: const Value(1.0),
        fatCaloriePct: const Value(25.0),
        sex: const Value('male'),
        heightCm: const Value(178),
        birthdate: const Value('1996-01-01'),
        activityLevel: const Value(3),
        onboardingCompleted: const Value(1),
        updatedAt: Value(DateTime.now().toIso8601String()),
      ));
      await db.insertWeight(BodyweightEntriesCompanion.insert(
        weightKg: 80,
        loggedAt: DateTime.now().toIso8601String(),
      ));

      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
        ],
      );
      addTearDown(() => container.dispose());

      final targets = await container.read(macroTargetsProvider.future);

      expect(targets.maintenanceCalories, isNotNull);
      expect(targets.targetCalories,
          closeTo(targets.maintenanceCalories! - 500, 1));
      expect(targets.calorieAdjustment, closeTo(-500, 1));
    });

    test('pre-onboarding with no bodyweight uses safe floor', () async {
      final db = AppDatabase.createInMemory();
      addTearDown(() => db.close());

      await db.upsertGoals(UserGoalsCompanion(
        goalType: const Value('cut'),
        calorieAdjustment: const Value(-500),
        proteinGPerLb: const Value(1.0),
        fatCaloriePct: const Value(25.0),
        onboardingCompleted: const Value(0),
        updatedAt: Value(DateTime.now().toIso8601String()),
      ));

      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
        ],
      );
      addTearDown(() => container.dispose());

      final targets = await container.read(macroTargetsProvider.future);

      expect(targets.maintenanceCalories, isNull);
      expect(targets.targetCalories, closeTo(1200, 1));
    });
  });
}
