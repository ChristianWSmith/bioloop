import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;

import 'package:bioloop/core/database/database.dart';
import 'package:bioloop/providers/database_provider.dart';
import 'package:bioloop/providers/goals_provider.dart';
import 'package:bioloop/providers/unit_preferences_provider.dart';

void main() {
  group('UnitPreferences.proteinUnitForBasis', () {
    test('imperial bodyweight returns g/lb', () {
      expect(UnitPreferences.imperial().proteinUnitForBasis('bodyweight'), 'g/lb');
    });

    test('metric bodyweight returns g/kg', () {
      expect(UnitPreferences.metric().proteinUnitForBasis('bodyweight'), 'g/kg');
    });

    test('imperial height returns g/cm', () {
      expect(UnitPreferences.imperial().proteinUnitForBasis('height'), 'g/cm');
    });

    test('metric height returns g/cm', () {
      expect(UnitPreferences.metric().proteinUnitForBasis('height'), 'g/cm');
    });
  });

  group('UserGoals.proteinBasis default', () {
    test('new goals row has proteinBasis = bodyweight by default', () async {
      final db = AppDatabase.createInMemory();
      addTearDown(() => db.close());

      await db.upsertGoals(UserGoalsCompanion(
        goalType: const Value('cut'),
        calorieAdjustment: const Value(-500),
        updatedAt: Value(DateTime.now().toIso8601String()),
      ));

      final goals = await db.getGoals();
      expect(goals, isNotNull);
      expect(goals!.proteinBasis, 'bodyweight');
    });

    test('proteinBasis can be set to height', () async {
      final db = AppDatabase.createInMemory();
      addTearDown(() => db.close());

      await db.upsertGoals(UserGoalsCompanion(
        goalType: const Value('cut'),
        calorieAdjustment: const Value(-500),
        proteinBasis: const Value('height'),
        updatedAt: Value(DateTime.now().toIso8601String()),
      ));

      final goals = await db.getGoals();
      expect(goals, isNotNull);
      expect(goals!.proteinBasis, 'height');
    });
  });

  group('unitPreferencesProvider with proteinBasis', () {
    test('provider returns correct unit for bodyweight basis', () async {
      final db = AppDatabase.createInMemory();
      addTearDown(() => db.close());

      await db.upsertGoals(UserGoalsCompanion(
        goalType: const Value('cut'),
        useImperial: const Value(1),
        updatedAt: Value(DateTime.now().toIso8601String()),
      ));

      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
      addTearDown(() => container.dispose());

      // Wait for userGoalsProvider to resolve before reading unitPreferencesProvider
      await container.read(userGoalsProvider.future);

      final prefs = container.read(unitPreferencesProvider);
      expect(prefs.proteinUnitForBasis('bodyweight'), 'g/lb');
      expect(prefs.proteinUnitForBasis('height'), 'g/cm');
    });

    test('provider returns correct unit for metric + bodyweight', () async {
      final db = AppDatabase.createInMemory();
      addTearDown(() => db.close());

      await db.upsertGoals(UserGoalsCompanion(
        goalType: const Value('cut'),
        useImperial: const Value(0),
        updatedAt: Value(DateTime.now().toIso8601String()),
      ));

      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
      addTearDown(() => container.dispose());

      await container.read(userGoalsProvider.future);

      final prefs = container.read(unitPreferencesProvider);
      expect(prefs.proteinUnitForBasis('bodyweight'), 'g/kg');
      expect(prefs.proteinUnitForBasis('height'), 'g/cm');
    });
  });
}
