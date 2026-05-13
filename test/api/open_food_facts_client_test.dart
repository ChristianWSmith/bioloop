import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bioloop/core/api/models/food_result.dart';
import 'package:bioloop/core/api/open_food_facts_client.dart';

Map<String, dynamic> _sampleProduct() => {
      'product_name': 'Chicken Breast',
      'serving_size': '100g',
      'nutriments': {
        'energy-kcal_serving': 165,
        'proteins_serving': 31,
        'carbohydrates_serving': 0,
        'fat_serving': 3.6,
        'energy-kcal_100g': 165,
        'proteins_100g': 31,
        'carbohydrates_100g': 0,
        'fat_100g': 3.6,
      },
      'code': '123456789',
    };

Map<String, dynamic> _sampleSearchResponse() => {
      'products': [_sampleProduct()],
    };

Map<String, dynamic> _sampleProductResponse() => {
      'product': _sampleProduct(),
      'code': '123456789',
    };

Map<String, dynamic> _productMissingServing() => {
      'product_name': 'Oats',
      'nutriments': {
        'energy-kcal_100g': 389,
        'proteins_100g': 16.9,
        'carbohydrates_100g': 66.3,
        'fat_100g': 6.9,
      },
      'code': '987654321',
    };

void main() {
  group('FoodResult.fromJson', () {
    test('parses _serving fields correctly', () {
      final result = FoodResult.fromJson(_sampleProduct());
      expect(result.name, 'Chicken Breast');
      expect(result.servingLabel, '100g');
      expect(result.servingSizeGrams, 100);
      expect(result.caloriesPerServing, 165);
      expect(result.proteinPerServing, 31);
      expect(result.carbsPerServing, 0);
      expect(result.fatPerServing, 3.6);
      expect(result.barcode, '123456789');
      expect(result.source, 'open_food_facts');
    });

    test('falls back to _100g fields when _serving fields missing', () {
      final result = FoodResult.fromJson(_productMissingServing());
      expect(result.name, 'Oats');
      expect(result.servingLabel, '100g');
      expect(result.servingSizeGrams, 100);
      expect(result.caloriesPerServing, 389);
      expect(result.proteinPerServing, 16.9);
      expect(result.carbsPerServing, 66.3);
      expect(result.fatPerServing, 6.9);
      expect(result.barcode, '987654321');
    });

    test('sets servingLabel to 100g in fallback even when serving_size exists',
        () {
      final json = {
        ..._productMissingServing(),
        'serving_size': '1 cup',
      };
      final result = FoodResult.fromJson(json);
      expect(result.servingLabel, '100g');
      expect(result.servingSizeGrams, 100);
    });

    test('handles missing product_name', () {
      final json = <String, dynamic>{
        'nutriments': _sampleProduct()['nutriments'],
      };
      final result = FoodResult.fromJson(json);
      expect(result.name, 'Unknown');
    });

    test('handles null nutriments', () {
      final json = <String, dynamic>{'product_name': 'Test'};
      final result = FoodResult.fromJson(json);
      expect(result.name, 'Test');
      expect(result.caloriesPerServing, 0);
    });

    test('parses grams from serving_size like "1 bar (40g)"', () {
      final json = {
        ..._sampleProduct(),
        'serving_size': '1 bar (40g)',
      };
      final result = FoodResult.fromJson(json);
      expect(result.servingSizeGrams, 40);
    });
  });

  group('OpenFoodFactsClient', () {
    late OpenFoodFactsClient client;

    test('search returns parsed results', () async {
      final mock = MockClient((_) async {
        return http.Response(jsonEncode(_sampleSearchResponse()), 200);
      });
      client = OpenFoodFactsClient(client: mock);

      final results = await client.search('chicken');
      expect(results.length, 1);
      expect(results.first.name, 'Chicken Breast');
    });

    test('getByBarcode returns single product', () async {
      final mock = MockClient((_) async {
        return http.Response(jsonEncode(_sampleProductResponse()), 200);
      });
      client = OpenFoodFactsClient(client: mock);

      final result = await client.getByBarcode('3017620422003');
      expect(result, isNotNull);
      expect(result!.name, 'Chicken Breast');
    });

    test('search returns empty on empty products', () async {
      final mock = MockClient((_) async {
        return http.Response(jsonEncode({'products': []}), 200);
      });
      client = OpenFoodFactsClient(client: mock);

      final results = await client.search('nonexistent');
      expect(results, isEmpty);
    });

    test('search returns empty on non-200 status', () async {
      final mock = MockClient((_) async {
        return http.Response('Not Found', 404);
      });
      client = OpenFoodFactsClient(client: mock);

      final results = await client.search('anything');
      expect(results, isEmpty);
    });

    test('search returns empty on 429', () async {
      final mock = MockClient((_) async {
        return http.Response('Too Many Requests', 429);
      });
      client = OpenFoodFactsClient(client: mock);

      final results = await client.search('anything');
      expect(results, isEmpty);
    });

    test('getByBarcode returns null on 429', () async {
      final mock = MockClient((_) async {
        return http.Response('Too Many Requests', 429);
      });
      client = OpenFoodFactsClient(client: mock);

      final result = await client.getByBarcode('123');
      expect(result, isNull);
    });

    test('getByBarcode returns null when product field missing', () async {
      final mock = MockClient((_) async {
        return http.Response(jsonEncode({'code': '123'}), 200);
      });
      client = OpenFoodFactsClient(client: mock);

      final result = await client.getByBarcode('123');
      expect(result, isNull);
    });

    test('handles malformed JSON gracefully', () async {
      final mock = MockClient((_) async {
        return http.Response('not json', 200);
      });
      client = OpenFoodFactsClient(client: mock);

      final results = await client.search('anything');
      expect(results, isEmpty);
    });
  });
}
