import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'models/food_result.dart';

const String _defaultBaseUrl = 'https://world.openfoodfacts.org';
const String _defaultUserAgent = 'bioloop/1.0';

class OpenFoodFactsClient {
  final http.Client _client;
  final String baseUrl;
  final String userAgent;

  OpenFoodFactsClient({
    http.Client? client,
    this.baseUrl = _defaultBaseUrl,
    this.userAgent = _defaultUserAgent,
  }) : _client = client ?? http.Client();

  Future<List<FoodResult>> search(String query) async {
    try {
      final uri = Uri.parse(
        '$baseUrl/cgi/search.pl?search_terms=${Uri.encodeQueryComponent(query)}&json=true&page_size=25&lc=en&cc=US',
      );
      final response = await _client
          .get(uri, headers: {'User-Agent': userAgent})
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 429) return [];
      if (response.statusCode != 200) return [];

      final body = jsonDecode(response.body) as Map<String, dynamic>?;
      if (body == null) return [];

      final products = body['products'] as List<dynamic>?;
      if (products == null) return [];

      return products
          .map((p) => FoodResult.fromJson(p as Map<String, dynamic>))
          .toList();
    } on SocketException {
      return [];
    } on HttpException {
      return [];
    } on FormatException {
      return [];
    }
  }

  Future<FoodResult?> getByBarcode(String barcode) async {
    try {
      final uri = Uri.parse('$baseUrl/api/v2/product/$barcode.json');
      final response = await _client
          .get(uri, headers: {'User-Agent': userAgent})
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 429) return null;
      if (response.statusCode != 200) return null;

      final body = jsonDecode(response.body) as Map<String, dynamic>?;
      if (body == null) return null;

      final product = body['product'] as Map<String, dynamic>?;
      if (product == null) return null;

      return FoodResult.fromJson(product);
    } on SocketException {
      return null;
    } on HttpException {
      return null;
    } on FormatException {
      return null;
    }
  }
}
