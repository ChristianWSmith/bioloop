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

    test('dedup: no duplicate barcodes, local results first', () async {
      final now = DateTime.now().toIso8601String();
      await db.into(db.foods).insert(FoodsCompanion.insert(
        name: 'Chicken Breast',
        servingLabel: '100g',
        caloriesPerServing: 165,
        proteinPerServing: 31,
        carbsPerServing: 0,
        fatPerServing: 3.6,
        barcode: Value('123'),
        createdAt: now,
      ));

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
            {
              'product_name': 'Pork Chop',
              'nutriments': {
                'energy-kcal_serving': 200,
                'proteins_serving': 22,
                'carbohydrates_serving': 0,
                'fat_serving': 12,
              },
              'code': '789',
            },
          ],
        }), 200);
      });
      final mockApiClient = OpenFoodFactsClient(client: mock);
      final service = FoodSearchService(db: db, apiClient: mockApiClient);

      final results = await service.search('chicken');

      expect(results.length, 3);
      expect(results[0].localId, isNotNull);
      expect(results[0].name, 'Chicken Breast');
      expect(results[0].source, 'manual');
      expect(results[1].localId, isNull);
      expect(results[2].localId, isNull);

      final barcodes = results.map((r) => r.barcode).toSet();
      expect(barcodes.length, 3);
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
        servingSizeGrams: 100,
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

    test('local-first: no API call when local results >= 25', () async {
      final now = DateTime.now().toIso8601String();
      for (var i = 0; i < 25; i++) {
        await db.into(db.foods).insert(FoodsCompanion.insert(
          name: 'Food $i',
          servingLabel: '100g',
          caloriesPerServing: 100.0,
          proteinPerServing: 10.0,
          carbsPerServing: 10.0,
          fatPerServing: 1.0,
          createdAt: now,
        ));
      }

      int apiCallCount = 0;
      final mock = MockClient((_) async {
        apiCallCount++;
        return http.Response(jsonEncode({'products': []}), 200);
      });
      final mockApiClient = OpenFoodFactsClient(client: mock);
      final service = FoodSearchService(db: db, apiClient: mockApiClient);

      final results = await service.search('Food');

      expect(results.length, 25);
      expect(apiCallCount, 0);
    });

    test('empty query returns empty list', () async {
      final mockApiClient = OpenFoodFactsClient(
        client: MockClient((_) async => http.Response('{}', 200)),
      );
      final service = FoodSearchService(db: db, apiClient: mockApiClient);

      final results = await service.search('');
      expect(results, isEmpty);

      final results2 = await service.search('   ');
      expect(results2, isEmpty);
    });
  });
}
