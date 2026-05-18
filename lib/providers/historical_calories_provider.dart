import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'food_log_provider.dart';
import 'reset_provider.dart';
import 'data_trigger_provider.dart';

final historicalCaloriesProvider = FutureProvider<List<({String date, double calories})>>((ref) async {
  ref.watch(resetTriggerProvider);
  ref.watch(dataTriggerProvider);
  final logService = ref.read(foodLogProvider);
  final now = DateTime.now();
  final thirtyDaysAgo = now.subtract(const Duration(days: 30));
  final entries = await logService.getEntriesForDateRange(thirtyDaysAgo, now);
  
  final dailyTotals = <String, double>{};
  for (final entry in entries) {
    final dateStr = entry.loggedAt.substring(0, 10);
    dailyTotals[dateStr] = (dailyTotals[dateStr] ?? 0) + entry.calories;
  }
  
  return dailyTotals.entries.map((e) => (date: e.key, calories: e.value)).toList();
});
