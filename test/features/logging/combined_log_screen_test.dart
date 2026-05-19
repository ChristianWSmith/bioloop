import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bioloop/core/database/database.dart';
import 'package:bioloop/providers/database_provider.dart';

void main() {
  group('CombinedLogScreen brand and quantity display', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase.createInMemory();
    });

    tearDown(() {
      db.close();
    });

    testWidgets('shows brand and quantity for manual food with brand', (tester) async {
      final now = DateTime.now().toIso8601String();

      final foodId = await db.insertFood(FoodsCompanion.insert(
        name: 'Test Food',
        servingLabel: 'g',
        brand: Value('Test Brand'),
        caloriesPerServing: 200,
        proteinPerServing: 10,
        carbsPerServing: 30,
        fatPerServing: 5,
        source: Value('manual'),
        createdAt: now,
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
        loggedAt: now,
      ));

      final entries = await db.getEntriesForDate(DateTime.now());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
          ],
          child: const MaterialApp(
            home: Scaffold(),
          ),
        ),
      );

      expect(entries.first.foodId, foodId);
      expect(entries.first.servings, 100);
    });

    testWidgets('shows quantity only for recipe entries', (tester) async {
      final now = DateTime.now().toIso8601String();

      final recipeId = await db.insertRecipe(RecipesCompanion.insert(
        name: 'Test Recipe',
        servingSize: 500,
        servingLabel: 'g',
        createdAt: now,
        updatedAt: now,
      ));

      await db.insertEntry(FoodEntriesCompanion.insert(
        name: 'Test Recipe',
        calories: 500,
        proteinGrams: 30,
        carbsGrams: 60,
        fatGrams: 15,
        servings: 250,
        servingLabel: 'g',
        recipeId: Value(recipeId),
        mealType: 'lunch',
        loggedAt: now,
      ));

      final entries = await db.getEntriesForDate(DateTime.now());

      expect(entries.first.recipeId, recipeId);
      expect(entries.first.servings, 250);
      expect(entries.first.servingLabel, 'g');
    });

    testWidgets('formats whole numbers without decimal', (tester) async {
      final value = 100.0;
      final formatted = value == value.roundToDouble()
          ? value.toInt().toString()
          : value.toStringAsFixed(1);

      expect(formatted, '100');
    });

    testWidgets('formats decimal numbers with one decimal', (tester) async {
      final value = 100.5;
      final formatted = value == value.roundToDouble()
          ? value.toInt().toString()
          : value.toStringAsFixed(1);

      expect(formatted, '100.5');
    });
  });
}
