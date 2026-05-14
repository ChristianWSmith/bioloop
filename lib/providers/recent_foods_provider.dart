import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'food_search_provider.dart';
import 'database_provider.dart';

class RecentFoodItem {
  final FoodSearchItem food;
  final DateTime lastUsed;
  RecentFoodItem({required this.food, required this.lastUsed});
}

final recentFoodsProvider = FutureProvider<List<RecentFoodItem>>((ref) async {
  final db = ref.read(databaseProvider);
  final results = await db.getRecentFoods();

  return results.map((r) {
    return RecentFoodItem(
      food: FoodSearchItem.fromFood(r.food),
      lastUsed: DateTime.parse(r.lastUsed),
    );
  }).toList();
});
