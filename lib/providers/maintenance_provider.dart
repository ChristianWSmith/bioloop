import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/algorithms/maintenance_calculator.dart';
import 'database_provider.dart';

final maintenanceProvider = FutureProvider<MaintenanceResult?>((ref) async {
  final db = ref.watch(databaseProvider);
  final now = DateTime.now();
  final lookback = 30;

  final allFoodEntries = await db.getEntriesPaginated(limit: 365);
  final allWeights = await db.getWeights();

  return MaintenanceCalculator.calculate(
    foodEntries: allFoodEntries,
    weightEntries: allWeights,
    lookbackDays: lookback,
    now: now,
  );
});
