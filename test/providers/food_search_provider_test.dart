import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;

import 'package:bioloop/core/database/database.dart';
import 'package:bioloop/core/api/open_food_facts_client.dart';
import 'package:bioloop/providers/food_search_provider.dart';

void main() {
  group('FoodSearchService', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase.createInMemory();
    });

    tearDown(() {
      db.close();
    });

    test('searchLocal returns foods sorted by recency', () async {
      final now = DateTime.now().toIso8601String();
      // Insert 3 foods
      await db.into(db.foods).insert(FoodsCompanion.insert(
        name: 'Oats',
        servingLabel: '100g',
        caloriesPerServing: 389,
        proteinPerServing: 16.9,
        carbsPerServing: 66.3,
        fatPerServing: 6.9,
        createdAt: now,
      ));
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

      // Log entries to establish recency order: Oats first, then Chicken, then Rice
      await db.into(db.foodEntries).insert(FoodEntriesCompanion.insert(
        name: 'Oats',
        calories: 389,
        proteinGrams: 16.9,
        carbsGrams: 66.3,
        fatGrams: 6.9,
        servings: 1,
        servingLabel: '100g',
        mealType: 'breakfast',
        foodId: Value(1),
        loggedAt: '2026-05-14T08:00:00',
      ));
      await db.into(db.foodEntries).insert(FoodEntriesCompanion.insert(
        name: 'Chicken Breast',
        calories: 165,
        proteinGrams: 31,
        carbsGrams: 0,
        fatGrams: 3.6,
        servings: 1,
        servingLabel: '100g',
        mealType: 'lunch',
        foodId: Value(2),
        loggedAt: '2026-05-15T12:00:00',
      ));
      await db.into(db.foodEntries).insert(FoodEntriesCompanion.insert(
        name: 'Brown Rice',
        calories: 111,
        proteinGrams: 2.6,
        carbsGrams: 23,
        fatGrams: 0.9,
        servings: 1,
        servingLabel: '100g',
        mealType: 'dinner',
        foodId: Value(3),
        loggedAt: '2026-05-15T13:00:00',
      ));

      final mockApiClient = OpenFoodFactsClient(
        client: MockClient((_) async => http.Response('{}', 200)),
      );
      final service = FoodSearchService(db: db, apiClient: mockApiClient);

      // searchLocal with empty query returns all foods in recency order
      final allResults = await service.searchLocal('');
      expect(allResults.length, 3);
      // Most recently used first: Brown Rice (May 15 13:00), Chicken (May 15 12:00), Oats (May 14)
      expect(allResults[0].name, 'Brown Rice');
      expect(allResults[1].name, 'Chicken Breast');
      expect(allResults[2].name, 'Oats');

      // searchLocal with query filters correctly
      final filteredResults = await service.searchLocal('chicken');
      expect(filteredResults.length, 1);
      expect(filteredResults[0].name, 'Chicken Breast');
    });

    test('searchWeb returns API results only', () async {
      final mock = MockClient((_) async {
        return http.Response(jsonEncode({
          'products': [
            {
              'product_name': 'Chicken Breast',
              'nutriments': {
                'energy-kcal_serving': 165,
                'proteins_serving': 31,
                'carbohydrates_serving': 0,
                'fat_serving': 3.6,
              },
              'code': '123',
            },
            {
              'product_name': 'Beef Steak',
              'nutriments': {
                'energy-kcal_serving': 250,
                'proteins_serving': 26,
                'carbohydrates_serving': 0,
                'fat_serving': 15,
              },
              'code': '456',
            },
          ],
        }), 200);
      });
      final mockApiClient = OpenFoodFactsClient(client: mock);
      final service = FoodSearchService(db: db, apiClient: mockApiClient);

      final results = await service.searchWeb('chicken');

      expect(results.length, 2);
      expect(results[0].localId, isNull);
      expect(results[0].name, 'Chicken Breast');
      expect(results[0].source, 'open_food_facts');
      expect(results[1].name, 'Beef Steak');
    });

    test('searchWeb with empty query returns empty list', () async {
      final mockApiClient = OpenFoodFactsClient(
        client: MockClient((_) async => http.Response('{}', 200)),
      );
      final service = FoodSearchService(db: db, apiClient: mockApiClient);

      final results = await service.searchWeb('');
      expect(results, isEmpty);

      final results2 = await service.searchWeb('   ');
      expect(results2, isEmpty);
    });

    test('auto-save: saveApiResult inserts into foods table', () async {
      final service = FoodSearchService(
        db: db,
        apiClient: OpenFoodFactsClient(client: MockClient((_) async {
          return http.Response('{}', 200);
        })),
      );

      final item = FoodSearchItem(
        name: 'Oats',
        servingLabel: '100g',
        caloriesPerServing: 389,
        proteinPerServing: 16.9,
        carbsPerServing: 66.3,
        fatPerServing: 6.9,
        barcode: '987',
        source: 'open_food_facts',
      );

      final id = await service.saveApiResult(item);
      expect(id, greaterThan(0));

      final saved = await db.getByBarcode('987');
      expect(saved, isNotNull);
      expect(saved!.name, 'Oats');
      expect(saved.source, 'open_food_facts');
    });
  });
}
