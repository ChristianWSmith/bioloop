import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bioloop/core/database/database.dart';
import 'package:bioloop/features/history/widgets/edit_entry_sheet.dart';
import 'package:bioloop/providers/database_provider.dart';

void main() {
  group('EditEntrySheet', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase.createInMemory();
    });

    tearDown(() {
      db.close();
    });

    testWidgets('displays actual portion for recipe entries', (tester) async {
      final recipe = await db.insertRecipe(RecipesCompanion.insert(
        name: 'Test Recipe',
        servingSize: 1851,
        servingLabel: 'g',
        createdAt: DateTime.now().toIso8601String(),
        updatedAt: DateTime.now().toIso8601String(),
      ));

      await db.insertIngredient(RecipeIngredientsCompanion.insert(
        recipeId: recipe,
        foodId: 1,
        quantity: 100,
        createdAt: DateTime.now().toIso8601String(),
      ));

      await db.insertEntry(FoodEntriesCompanion.insert(
        name: 'Test Recipe',
        calories: 500,
        proteinGrams: 30,
        carbsGrams: 60,
        fatGrams: 15,
        servings: 500,
        servingLabel: 'g',
        recipeId: Value(recipe),
        mealType: 'lunch',
        loggedAt: DateTime.now().toIso8601String(),
      ));

      final entries = await db.getEntriesForDate(DateTime.now());
      final entry = entries.first;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: EditEntrySheet(entry: entry),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final servingsField = find.byKey(const Key('edit_servings_field'));
      expect(servingsField, findsOneWidget);

      final servingsText = tester.widget<TextField>(servingsField);
      expect(servingsText.controller?.text, equals('500'));
    });

    testWidgets('recalculates macros when portion changes (recipe)', (tester) async {
      final recipe = await db.insertRecipe(RecipesCompanion.insert(
        name: 'Test Recipe',
        servingSize: 1000,
        servingLabel: 'g',
        createdAt: DateTime.now().toIso8601String(),
        updatedAt: DateTime.now().toIso8601String(),
      ));

      await db.insertIngredient(RecipeIngredientsCompanion.insert(
        recipeId: recipe,
        foodId: 1,
        quantity: 100,
        createdAt: DateTime.now().toIso8601String(),
      ));

      final macros = await db.computeRecipeMacros(recipe);
      final scale = 500 / 1000;

      await db.insertEntry(FoodEntriesCompanion.insert(
        name: 'Test Recipe',
        calories: macros.calories * scale,
        proteinGrams: macros.proteinGrams * scale,
        carbsGrams: macros.carbsGrams * scale,
        fatGrams: macros.fatGrams * scale,
        servings: 500,
        servingLabel: 'g',
        recipeId: Value(recipe),
        mealType: 'lunch',
        loggedAt: DateTime.now().toIso8601String(),
      ));

      final entries = await db.getEntriesForDate(DateTime.now());
      final entry = entries.first;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: EditEntrySheet(entry: entry),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final initialCalories = find.text('500');
      expect(initialCalories, findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('edit_servings_field')),
        '1000',
      );
      await tester.pumpAndSettle();

      final updatedCalories = find.text('1000');
      expect(updatedCalories, findsOneWidget);
    });

    testWidgets('regular food entries still work (no regression)', (tester) async {
      final foodId = await db.insertFood(FoodsCompanion.insert(
        name: 'Test Food',
        servingLabel: 'g',
        servingQuantity: Value(100),
        servingUnit: Value('g'),
        caloriesPerServing: 200,
        proteinPerServing: 10,
        carbsPerServing: 30,
        fatPerServing: 5,
        source: Value('manual'),
        createdAt: DateTime.now().toIso8601String(),
      ));

      await db.insertEntry(FoodEntriesCompanion.insert(
        name: 'Test Food',
        calories: 200,
        proteinGrams: 10,
        carbsGrams: 30,
        fatGrams: 5,
        servings: 100,
        servingLabel: 'g',
        foodId: Value(foodId),
        mealType: 'breakfast',
        loggedAt: DateTime.now().toIso8601String(),
      ));

      final entries = await db.getEntriesForDate(DateTime.now());
      final entry = entries.first;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: EditEntrySheet(entry: entry),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final servingsField = find.byKey(const Key('edit_servings_field'));
      expect(servingsField, findsOneWidget);

      final servingsText = tester.widget<TextField>(servingsField);
      expect(servingsText.controller?.text, equals('100'));

      expect(find.text('200'), findsOneWidget);
    });
  });
}
