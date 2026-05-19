import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';

import 'package:bioloop/core/database/database.dart';

void main() {
  group('searchLocalByRecency', () {
    test('unlogged foods appear before logged foods', () async {
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
      // Unlogged foods first (order between them by createdAt, which is same)
      expect(results[0].name, isIn(['Unlogged A', 'Unlogged B']));
      expect(results[1].name, isIn(['Unlogged A', 'Unlogged B']));
      // Logged food last
      expect(results[2].name, 'Logged C');
    });

    test('unlogged foods sorted by createdAt DESC', () async {
      final db = AppDatabase.createInMemory();
      addTearDown(() => db.close());

      // Insert older unlogged food first
      await db.into(db.foods).insert(FoodsCompanion.insert(
        name: 'Old Food',
        servingLabel: '100g',
        caloriesPerServing: 100,
        proteinPerServing: 10,
        carbsPerServing: 10,
        fatPerServing: 5,
        createdAt: '2026-01-01T00:00:00',
      ));
      // Insert newer unlogged food
      await db.into(db.foods).insert(FoodsCompanion.insert(
        name: 'New Food',
        servingLabel: '100g',
        caloriesPerServing: 200,
        proteinPerServing: 20,
        carbsPerServing: 20,
        fatPerServing: 10,
        createdAt: '2026-06-01T00:00:00',
      ));

      final results = await db.searchLocalByRecency();

      expect(results.length, 2);
      expect(results[0].name, 'New Food');
      expect(results[1].name, 'Old Food');
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

    test('source does not affect ordering within unlogged group', () async {
      final db = AppDatabase.createInMemory();
      addTearDown(() => db.close());

      // Manual food created first (older)
      await db.into(db.foods).insert(FoodsCompanion.insert(
        name: 'Manual Old',
        servingLabel: '100g',
        caloriesPerServing: 100,
        proteinPerServing: 10,
        carbsPerServing: 10,
        fatPerServing: 5,
        source: const Value('manual'),
        createdAt: '2026-01-01T00:00:00',
      ));
      // OFF food created later (newer)
      await db.into(db.foods).insert(FoodsCompanion.insert(
        name: 'OFF New',
        servingLabel: '100g',
        caloriesPerServing: 200,
        proteinPerServing: 20,
        carbsPerServing: 20,
        fatPerServing: 10,
        source: const Value('open_food_facts'),
        createdAt: '2026-06-01T00:00:00',
      ));

      final results = await db.searchLocalByRecency();

      expect(results.length, 2);
      // Newer OFF food should appear before older manual food
      expect(results[0].name, 'OFF New');
      expect(results[1].name, 'Manual Old');
    });

    test('query filters across both groups', () async {
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
        createdAt: now,
      ));
      await db.into(db.foods).insert(FoodsCompanion.insert(
        name: 'Brown Rice',
        servingLabel: '100g',
        caloriesPerServing: 111,
        proteinPerServing: 2.6,
        carbsPerServing: 23,
        fatPerServing: 0.9,
        createdAt: now,
      ));
      await db.into(db.foods).insert(FoodsCompanion.insert(
        name: 'Chicken Thigh',
        servingLabel: '100g',
        caloriesPerServing: 200,
        proteinPerServing: 25,
        carbsPerServing: 0,
        fatPerServing: 12,
        createdAt: now,
      ));

      // Log only Brown Rice
      await db.into(db.foodEntries).insert(FoodEntriesCompanion.insert(
        name: 'Brown Rice',
        calories: 111,
        proteinGrams: 2.6,
        carbsGrams: 23,
        fatGrams: 0.9,
        servings: 1,
        servingLabel: '100g',
        mealType: 'lunch',
        foodId: const Value(2),
        loggedAt: '2026-05-16T12:00:00',
      ));

      final results = await db.searchLocalByRecency(query: 'chicken');

      expect(results.length, 2);
      // Both unlogged chicken foods, sorted by createdAt (same, so insertion order)
      expect(results[0].name, 'Chicken Breast');
      expect(results[1].name, 'Chicken Thigh');
    });

    test('limit is applied after sorting and filtering', () async {
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
