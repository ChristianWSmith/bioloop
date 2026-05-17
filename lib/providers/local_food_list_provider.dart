import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/data_trigger_provider.dart';
import '../providers/food_search_provider.dart';

final localFoodListProvider = FutureProvider.family<List<FoodSearchItem>, String>((ref, query) async {
  ref.watch(dataTriggerProvider);
  final service = ref.watch(foodSearchServiceProvider);
  return service.searchLocal(query);
});
