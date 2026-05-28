import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/algorithms/maintenance_calculator.dart';
import 'data_trigger_provider.dart';
import 'database_provider.dart';
import 'reset_provider.dart';

final maintenanceProvider = FutureProvider<MaintenanceResult?>((ref) async {
  ref.watch(resetTriggerProvider);
  ref.watch(dataTriggerProvider);
  final db = ref.watch(databaseProvider);
  final now = DateTime.now().subtract(const Duration(days: 1));
  
  // Use 90-day lookback (3 months max)
  // Algorithm internally uses rolling window within this period
  final lookback = 90;

  // Fetch reasonable limits (prevent loading years of data)
  final allFoodEntries = await db.getEntriesPaginated(limit: 500);
  final allWeights = await db.getWeights(limit: 200);

  return MaintenanceCalculator.calculate(
    foodEntries: allFoodEntries,
    weightEntries: allWeights,
    lookbackDays: lookback,
    now: now,
  );
});
