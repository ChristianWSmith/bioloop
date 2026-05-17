import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api/open_food_facts_client.dart';
import '../core/api/models/food_result.dart';
import '../core/database/database.dart';
import '../core/utils/calorie_clamp.dart';
import 'database_provider.dart';

final openFoodFactsClientProvider = Provider<OpenFoodFactsClient>((ref) {
  return OpenFoodFactsClient();
});

class FoodSearchItem {
  final int? localId;
  final String name;
  final String servingLabel;
  final double servingQuantity;
  final String servingUnit;
  final double caloriesPerServing;
  final double proteinPerServing;
  final double carbsPerServing;
  final double fatPerServing;
  final String? barcode;
  final String? brand;
  final String source;

  FoodSearchItem({
    this.localId,
    required this.name,
    required this.servingLabel,
    this.servingQuantity = 1.0,
    this.servingUnit = 'serving',
    required this.caloriesPerServing,
    required this.proteinPerServing,
    required this.carbsPerServing,
    required this.fatPerServing,
    this.barcode,
    this.brand,
    this.source = 'manual',
  });

  factory FoodSearchItem.fromFood(Food food) => FoodSearchItem(
        localId: food.id,
        name: food.name,
        servingLabel: food.servingLabel,
        servingQuantity: food.servingQuantity,
        servingUnit: food.servingUnit,
        caloriesPerServing: food.caloriesPerServing,
        proteinPerServing: food.proteinPerServing,
        carbsPerServing: food.carbsPerServing,
        fatPerServing: food.fatPerServing,
        barcode: food.barcode,
        brand: food.brand,
        source: food.source,
      );

  factory FoodSearchItem.fromFoodResult(FoodResult result) {
    final clampedCalories = clampCaloriesToMacros(
      calories: result.caloriesPerServing,
      protein: result.proteinPerServing,
      carbs: result.carbsPerServing,
      fat: result.fatPerServing,
    );
    return FoodSearchItem(
      name: result.name,
      servingLabel: result.servingLabel,
      servingQuantity: result.servingQuantity,
      servingUnit: result.servingUnit,
      caloriesPerServing: clampedCalories,
      proteinPerServing: result.proteinPerServing,
      carbsPerServing: result.carbsPerServing,
      fatPerServing: result.fatPerServing,
      barcode: result.barcode,
      brand: result.brand,
      source: result.source,
    );
  }
}

sealed class WebSearchResult {}

class WebSearchSuccess extends WebSearchResult {
  final List<FoodSearchItem> items;
  WebSearchSuccess(this.items);
}

class WebSearchFailure extends WebSearchResult {
  WebSearchFailure();
}

class FoodSearchService {
  final AppDatabase db;
  final OpenFoodFactsClient apiClient;

  FoodSearchService({required this.db, required this.apiClient});

  Future<List<FoodSearchItem>> searchLocal(String query) async {
    final results = await db.searchLocalByRecency(query: query.isEmpty ? null : query);
    return results.map(FoodSearchItem.fromFood).toList();
  }

  Future<WebSearchResult> searchWeb(String query) async {
    if (query.trim().isEmpty) return WebSearchSuccess([]);
    try {
      final results = await apiClient.search(query);
      return WebSearchSuccess(
        results.map(FoodSearchItem.fromFoodResult).toList(),
      );
    } catch (_) {
      return WebSearchFailure();
    }
  }

  Future<int> saveApiResult(FoodSearchItem item) async {
      final clampedCalories = clampCaloriesToMacros(
        calories: item.caloriesPerServing,
        protein: item.proteinPerServing,
        carbs: item.carbsPerServing,
        fat: item.fatPerServing,
      );
      return await db.insertFood(FoodsCompanion.insert(
        name: item.name,
        servingLabel: item.servingLabel,
        servingQuantity: Value(item.servingQuantity),
        servingUnit: Value(item.servingUnit),
        caloriesPerServing: clampedCalories,
        proteinPerServing: item.proteinPerServing,
        carbsPerServing: item.carbsPerServing,
        fatPerServing: item.fatPerServing,
        barcode: Value(item.barcode),
        brand: Value(item.brand),
        source: Value(item.source),
        createdAt: DateTime.now().toIso8601String(),
      ));
  }
}

final foodSearchServiceProvider = Provider<FoodSearchService>((ref) {
  return FoodSearchService(
    db: ref.read(databaseProvider),
    apiClient: ref.read(openFoodFactsClientProvider),
  );
});
