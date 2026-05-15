import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:bioloop/core/api/open_food_facts_client.dart';

void main() {
  group('getByBarcode API', () {
    test('returns food for known barcode', () async {
      final mock = MockClient((request) async {
        return http.Response(jsonEncode({
          'product': {
            'product_name': 'Nutella',
            'nutriments': {
              'energy-kcal_serving': 200,
              'proteins_serving': 3,
              'carbohydrates_serving': 22,
              'fat_serving': 11,
            },
            'code': '3017620422003',
          },
        }), 200);
      });
      final client = OpenFoodFactsClient(client: mock);

      final result = await client.getByBarcode('3017620422003');
      expect(result, isNotNull);
      expect(result!.name, 'Nutella');
      expect(result.barcode, '3017620422003');
      expect(result.caloriesPerServing, 200);
    });

    test('returns null for unknown barcode', () async {
      final mock = MockClient((request) async {
        return http.Response(jsonEncode({'status': 0}), 200);
      });
      final client = OpenFoodFactsClient(client: mock);

      final result = await client.getByBarcode('0000000000000');
      expect(result, isNull);
    });

    test('returns null on 404', () async {
      final mock =
          MockClient((_) async => http.Response('Not Found', 404));
      final client = OpenFoodFactsClient(client: mock);

      final result = await client.getByBarcode('3017620422003');
      expect(result, isNull);
    });

    test('returns null on 429 rate limit', () async {
      final mock = MockClient(
          (_) async => http.Response('Too Many Requests', 429));
      final client = OpenFoodFactsClient(client: mock);

      final result = await client.getByBarcode('3017620422003');
      expect(result, isNull);
    });
  });
}
