import 'package:drift/drift.dart' hide isNull;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bioloop/core/database/database.dart';
import 'package:bioloop/features/settings/settings_screen.dart';
import 'package:bioloop/providers/database_provider.dart';

Future<AppDatabase> createSeedDb() async {
  final db = AppDatabase.createInMemory();
  final now = DateTime.now().toIso8601String();
  await db.into(db.foods).insert(FoodsCompanion.insert(
    name: 'Chicken Breast',
    servingLabel: '100g',
    caloriesPerServing: 165,
    proteinPerServing: 31,
    carbsPerServing: 0,
    fatPerServing: 3.6,
    createdAt: now,
  ));
  await db.into(db.foodEntries).insert(FoodEntriesCompanion.insert(
    name: 'Test Entry',
    calories: 500,
    proteinGrams: 25,
    carbsGrams: 50,
    fatGrams: 20,
    servings: 1,
    servingLabel: 'serving',
    mealType: 'lunch',
    loggedAt: now,
  ));
  await db.into(db.bodyweightEntries).insert(BodyweightEntriesCompanion.insert(
    weightKg: 75,
    loggedAt: now,
  ));
  await db.into(db.userGoals).insert(UserGoalsCompanion(
    goalType: const Value('cut'),
    calorieAdjustment: const Value<double?>(-500),
    onboardingCompleted: const Value(1),
    updatedAt: Value(now),
  ));
  await db.into(db.mealTemplates).insert(MealTemplatesCompanion.insert(
    name: 'Test Template',
    foods: '[]',
    createdAt: now,
  ));
  final recipeId = await db.into(db.recipes).insert(RecipesCompanion.insert(
    name: 'Test Recipe',
    servingSize: 400,
    servingLabel: 'g',
    createdAt: now,
    updatedAt: now,
  ));
  await db.into(db.recipeIngredients).insert(RecipeIngredientsCompanion.insert(
    recipeId: recipeId,
    foodId: 1,
    quantity: 2,
    createdAt: now,
  ));
  return db;
}

Future<int> countTable(AppDatabase db, String table) async {
  switch (table) {
    case 'foods':
      return (await db.select(db.foods).get()).length;
    case 'food_entries':
      return (await db.select(db.foodEntries).get()).length;
    case 'bodyweight_entries':
      return (await db.select(db.bodyweightEntries).get()).length;
    case 'user_goals':
      return (await db.select(db.userGoals).get()).length;
    case 'meal_templates':
      return (await db.select(db.mealTemplates).get()).length;
    case 'recipes':
      return (await db.select(db.recipes).get()).length;
    case 'recipe_ingredients':
      return (await db.select(db.recipeIngredients).get()).length;
    default:
      return 0;
  }
}

void main() {
  group('resetAll()', () {
    test('truncates all 7 tables', () async {
      final db = await createSeedDb();

      expect(await countTable(db, 'foods'), greaterThan(0));
      expect(await countTable(db, 'food_entries'), greaterThan(0));
      expect(await countTable(db, 'bodyweight_entries'), greaterThan(0));
      expect(await countTable(db, 'user_goals'), greaterThan(0));
      expect(await countTable(db, 'meal_templates'), greaterThan(0));
      expect(await countTable(db, 'recipes'), greaterThan(0));
      expect(await countTable(db, 'recipe_ingredients'), greaterThan(0));

      await db.resetAll();

      expect(await countTable(db, 'foods'), 0);
      expect(await countTable(db, 'food_entries'), 0);
      expect(await countTable(db, 'bodyweight_entries'), 0);
      expect(await countTable(db, 'user_goals'), 0);
      expect(await countTable(db, 'meal_templates'), 0);
      expect(await countTable(db, 'recipes'), 0);
      expect(await countTable(db, 'recipe_ingredients'), 0);

      await db.close();
    });

    test('idempotent — calling twice does not crash', () async {
      final db = await createSeedDb();

      await db.resetAll();
      await db.resetAll();

      expect(await countTable(db, 'foods'), 0);
      expect(await countTable(db, 'food_entries'), 0);

      await db.close();
    });

    test('reset clears onboarding flag', () async {
      final db = await createSeedDb();

      var goals = await db.getGoals();
      expect(goals?.onboardingCompleted, 1);

      await db.resetAll();

      goals = await db.getGoals();
      expect(goals, isNull);
      await db.close();
    });
  });

  group('Settings screen', () {
    Widget buildTestApp(AppDatabase db) {
      return ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
        ],
        child: const MaterialApp(
          home: SettingsScreen(),
        ),
      );
    }

    testWidgets('shows reset option', (tester) async {
      final db = AppDatabase.createInMemory();
      addTearDown(() => db.close());

      await tester.pumpWidget(buildTestApp(db));
      await tester.pumpAndSettle();

      expect(find.text('Reset All Data'), findsOneWidget);
      expect(find.text('Delete everything and start fresh'), findsOneWidget);
    });

    testWidgets('tap reset shows confirmation dialog', (tester) async {
      final db = AppDatabase.createInMemory();
      addTearDown(() => db.close());

      await tester.pumpWidget(buildTestApp(db));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Reset All Data'));
      await tester.pumpAndSettle();

      expect(find.text('Reset All Data?'), findsOneWidget);
      expect(
        find.textContaining('This cannot be undone'),
        findsOneWidget,
      );
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Delete Everything'), findsOneWidget);
    });

    testWidgets('cancel does nothing', (tester) async {
      final db = await createSeedDb();
      addTearDown(() => db.close());

      await tester.pumpWidget(buildTestApp(db));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Reset All Data'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(await countTable(db, 'foods'), greaterThan(0));
      expect(await countTable(db, 'food_entries'), greaterThan(0));
    });

    testWidgets('confirm reset clears all data', (tester) async {
      final db = await createSeedDb();
      addTearDown(() => db.close());

      await tester.pumpWidget(buildTestApp(db));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Reset All Data'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Delete Everything'));
      await tester.pumpAndSettle();

      expect(await countTable(db, 'foods'), 0);
      expect(await countTable(db, 'food_entries'), 0);
      expect(await countTable(db, 'bodyweight_entries'), 0);
      expect(await countTable(db, 'user_goals'), 0);
      expect(await countTable(db, 'meal_templates'), 0);
      expect(await countTable(db, 'recipes'), 0);
      expect(await countTable(db, 'recipe_ingredients'), 0);
    });
  });

  group('Re-onboarding flow', () {
    testWidgets('after reset, onboarding screen appears when App checks goals',
        (tester) async {
      final db = await createSeedDb();
      addTearDown(() => db.close());

      var goals = await db.getGoals();
      expect(goals?.onboardingCompleted, 1);

      await db.resetAll();

      goals = await db.getGoals();
      expect(goals, isNull);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                return FutureBuilder<UserGoal?>(
                  future: db.getGoals(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Scaffold(
                          body: Center(child: CircularProgressIndicator()));
                    }
                    final onboarded =
                        snapshot.data?.onboardingCompleted == 1;
                    if (!onboarded) {
                      return const Scaffold(
                        body: Center(child: Text('Onboarding Screen')),
                      );
                    }
                    return const Scaffold(
                      body: Center(child: Text('Main App')),
                    );
                  },
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Onboarding Screen'), findsOneWidget);
      expect(find.text('Main App'), findsNothing);
    });
  });
}
