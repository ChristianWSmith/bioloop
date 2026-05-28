import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';

import 'package:bioloop/core/database/database.dart';

void main() {
  group('searchLocalByRecency', () {
    test('logged foods appear before unlogged foods', () async {
      final db = AppDatabase.createInMemory();
      addTearDown(() => db.close());

      final now = DateTime.now().toIso8601String();

      // Insert 2 unlogged foods
      await db.into(db.foods).insert(FoodsCompanion.insert(
        name: 'Unlogged A',
        servingLabel: '100g',
        caloriesPerServing: 100,
        proteinPerServing: 10,
        carbsPerServing: 10,
        fatPerServing: 5,
        source: const Value('manual'),
        createdAt: now,
      ));
      await db.into(db.foods).insert(FoodsCompanion.insert(
        name: 'Unlogged B',
        servingLabel: '100g',
        caloriesPerServing: 200,
        proteinPerServing: 20,
        carbsPerServing: 20,
        fatPerServing: 10,
        source: const Value('open_food_facts'),
        createdAt: now,
      ));

      // Insert 1 logged food
      await db.into(db.foods).insert(FoodsCompanion.insert(
        name: 'Logged C',
        servingLabel: '100g',
        caloriesPerServing: 300,
        proteinPerServing: 30,
        carbsPerServing: 30,
        fatPerServing: 15,
        createdAt: now,
      ));
      await db.into(db.foodEntries).insert(FoodEntriesCompanion.insert(
        name: 'Logged C',
        calories: 300,
        proteinGrams: 30,
        carbsGrams: 30,
        fatGrams: 15,
        servings: 1,
        servingLabel: '100g',
        mealType: 'lunch',
        foodId: const Value(3),
        loggedAt: '2026-05-16T12:00:00',
      ));

      final results = await db.searchLocalByRecency();

      expect(results.length, 3);
      // Logged food first
      expect(results[0].name, 'Logged C');
      // Unlogged foods sink to bottom
      expect(results[1].name, isIn(['Unlogged A', 'Unlogged B']));
      expect(results[2].name, isIn(['Unlogged A', 'Unlogged B']));
    });

    test('logged foods sorted by lastLoggedAt DESC', () async {
      final db = AppDatabase.createInMemory();
      addTearDown(() => db.close());

      final now = DateTime.now().toIso8601String();

      await db.into(db.foods).insert(FoodsCompanion.insert(
        name: 'Food A',
        servingLabel: '100g',
        caloriesPerServing: 100,
        proteinPerServing: 10,
        carbsPerServing: 10,
        fatPerServing: 5,
        createdAt: now,
      ));
      await db.into(db.foods).insert(FoodsCompanion.insert(
        name: 'Food B',
        servingLabel: '100g',
        caloriesPerServing: 200,
        proteinPerServing: 20,
        carbsPerServing: 20,
        fatPerServing: 10,
        createdAt: now,
      ));

      // Food A logged earlier
      await db.into(db.foodEntries).insert(FoodEntriesCompanion.insert(
        name: 'Food A',
        calories: 100,
        proteinGrams: 10,
        carbsGrams: 10,
        fatGrams: 5,
        servings: 1,
        servingLabel: '100g',
        mealType: 'lunch',
        foodId: const Value(1),
        loggedAt: '2026-05-10T12:00:00',
      ));
      // Food B logged more recently
      await db.into(db.foodEntries).insert(FoodEntriesCompanion.insert(
        name: 'Food B',
        calories: 200,
        proteinGrams: 20,
        carbsGrams: 20,
        fatGrams: 10,
        servings: 1,
        servingLabel: '100g',
        mealType: 'dinner',
        foodId: const Value(2),
        loggedAt: '2026-05-15T12:00:00',
      ));

      final results = await db.searchLocalByRecency();

      expect(results.length, 2);
      expect(results[0].name, 'Food B');
      expect(results[1].name, 'Food A');
    });

    test('unlogged foods sink to bottom, sorted by createdAt DESC', () async {
      final db = AppDatabase.createInMemory();
      addTearDown(() => db.close());

      final now = DateTime.now().toIso8601String();

      // Logged food (logged today)
      await db.into(db.foods).insert(FoodsCompanion.insert(
        name: 'Logged Food',
        servingLabel: '100g',
        caloriesPerServing: 300,
        proteinPerServing: 30,
        carbsPerServing: 30,
        fatPerServing: 15,
        createdAt: '2026-01-01T00:00:00',
      ));
      await db.into(db.foodEntries).insert(FoodEntriesCompanion.insert(
        name: 'Logged Food',
        calories: 300,
        proteinGrams: 30,
        carbsGrams: 30,
        fatGrams: 15,
        servings: 1,
        servingLabel: '100g',
        mealType: 'lunch',
        foodId: const Value(1),
        loggedAt: now,
      ));

      // Unlogged food created 2 days ago
      await db.into(db.foods).insert(FoodsCompanion.insert(
        name: 'Old Unlogged',
        servingLabel: '100g',
        caloriesPerServing: 100,
        proteinPerServing: 10,
        carbsPerServing: 10,
        fatPerServing: 5,
        createdAt: '2026-05-14T00:00:00',
      ));

      // Unlogged food created today (newer)
      await db.into(db.foods).insert(FoodsCompanion.insert(
        name: 'New Unlogged',
        servingLabel: '100g',
        caloriesPerServing: 200,
        proteinPerServing: 20,
        carbsPerServing: 20,
        fatPerServing: 10,
        createdAt: now,
      ));

      final results = await db.searchLocalByRecency();

      expect(results.length, 3);
      // Logged food first
      expect(results[0].name, 'Logged Food');
      // Unlogged foods sink, sorted by createdAt DESC
      expect(results[1].name, 'New Unlogged');
      expect(results[2].name, 'Old Unlogged');
    });

    test('fuzzy search matches brand name', () async {
      final db = AppDatabase.createInMemory();
      addTearDown(() => db.close());

      final now = DateTime.now().toIso8601String();

      // Food with brand
      await db.into(db.foods).insert(FoodsCompanion.insert(
        name: 'Chicken Breast',
        servingLabel: '100g',
        caloriesPerServing: 165,
        proteinPerServing: 31,
        carbsPerServing: 0,
        fatPerServing: 3.6,
        brand: const Value('Tyson'),
        createdAt: now,
      ));

      // Food without brand
      await db.into(db.foods).insert(FoodsCompanion.insert(
        name: 'Brown Rice',
        servingLabel: '100g',
        caloriesPerServing: 111,
        proteinPerServing: 2.6,
        carbsPerServing: 23,
        fatPerServing: 0.9,
        createdAt: now,
      ));

      // Search by brand name
      final results = await db.searchLocalByRecency(query: 'tyson');

      expect(results.length, 1);
      expect(results[0].name, 'Chicken Breast');
    });

    test('fuzzy search matches name OR brand', () async {
      final db = AppDatabase.createInMemory();
      addTearDown(() => db.close());

      final now = DateTime.now().toIso8601String();

      // Food A: name "Rice", no brand
      await db.into(db.foods).insert(FoodsCompanion.insert(
        name: 'Rice',
        servingLabel: '100g',
        caloriesPerServing: 111,
        proteinPerServing: 2.6,
        carbsPerServing: 23,
        fatPerServing: 0.9,
        createdAt: now,
      ));

      // Food B: name "Pasta", brand "Barilla"
      await db.into(db.foods).insert(FoodsCompanion.insert(
        name: 'Pasta',
        servingLabel: '100g',
        caloriesPerServing: 150,
        proteinPerServing: 5,
        carbsPerServing: 30,
        fatPerServing: 1,
        brand: const Value('Barilla'),
        createdAt: now,
      ));

      // Search by name
      final resultsByName = await db.searchLocalByRecency(query: 'rice');
      expect(resultsByName.length, 1);
      expect(resultsByName[0].name, 'Rice');

      // Search by brand
      final resultsByBrand = await db.searchLocalByRecency(query: 'barilla');
      expect(resultsByBrand.length, 1);
      expect(resultsByBrand[0].name, 'Pasta');
    });

    test('query filters by name or brand (case-insensitive)', () async {
      final db = AppDatabase.createInMemory();
      addTearDown(() => db.close());

      final now = DateTime.now().toIso8601String();

      await db.into(db.foods).insert(FoodsCompanion.insert(
        name: 'Chicken Breast',
        servingLabel: '100g',
        caloriesPerServing: 165,
        proteinPerServing: 31,
        carbsPerServing: 0,
        fatPerServing: 3.6,
        brand: const Value('TYSON'),
        createdAt: now,
      ));

      // Search lowercase should match uppercase brand
      final results = await db.searchLocalByRecency(query: 'tyson');

      expect(results.length, 1);
      expect(results[0].name, 'Chicken Breast');
    });

    test('limit is applied after sorting', () async {
      final db = AppDatabase.createInMemory();
      addTearDown(() => db.close());

      // Insert 5 unlogged foods with different createdAt
      for (var i = 0; i < 5; i++) {
        await db.into(db.foods).insert(FoodsCompanion.insert(
          name: 'Food $i',
          servingLabel: '100g',
          caloriesPerServing: 100.0 + i,
          proteinPerServing: 10.0,
          carbsPerServing: 10.0,
          fatPerServing: 5.0,
          createdAt: '2026-0${i + 1}-01T00:00:00',
        ));
      }

      final results = await db.searchLocalByRecency(limit: 3);

      expect(results.length, 3);
      // Should be the 3 most recently created
      expect(results[0].name, 'Food 4');
      expect(results[1].name, 'Food 3');
      expect(results[2].name, 'Food 2');
    });
  });
}
