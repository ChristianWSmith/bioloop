import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/algorithms/maintenance_calculator.dart';
import 'data_trigger_provider.dart';
import 'database_provider.dart';
import 'reset_provider.dart';

final maintenanceProvider = FutureProvider<MaintenanceResult?>((ref) async {
  ref.watch(resetTriggerProvider);
  ref.watch(dataTriggerProvider);
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
