import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/bodyweight_provider.dart';
import '../../providers/food_log_provider.dart';
import '../../providers/macro_targets_provider.dart';
import 'widgets/bodyweight_sparkline.dart';
import 'widgets/macro_ring.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entriesAsync = ref.watch(todaysFoodProvider);
    final targetsAsync = ref.watch(macroTargetsProvider);
    final weightsAsync = ref.watch(bodyweightProvider);

    return entriesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (entries) => targetsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (targets) {
          final consumedCals =
              entries.fold(0.0, (s, e) => s + e.calories);
          final consumedProtein =
              entries.fold(0.0, (s, e) => s + e.proteinGrams);
          final consumedFat =
              entries.fold(0.0, (s, e) => s + e.fatGrams);
          final consumedCarbs =
              entries.fold(0.0, (s, e) => s + e.carbsGrams);

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: Text(
                    "Today's Summary",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: MacroRing(
                    consumed: consumedCals,
                    target: targets.targetCalories,
                    label: 'Calories',
                    unit: 'kcal',
                    color: Theme.of(context).colorScheme.primary,
                    large: true,
                  ),
                ),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: MacroRing(
                          consumed: consumedProtein,
                          target: targets.proteinGrams,
                          label: 'Protein',
                          unit: 'g',
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: MacroRing(
                          consumed: consumedFat,
                          target: targets.fatGrams,
                          label: 'Fat',
                          unit: 'g',
                          color: Colors.orange,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: MacroRing(
                          consumed: consumedCarbs,
                          target: targets.carbsGrams,
                          label: 'Carbs',
                          unit: 'g',
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const Padding(
                  padding: EdgeInsets.only(left: 16, bottom: 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Bodyweight',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                weightsAsync.when(
                  loading: () => const SizedBox(
                    height: 200,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (_, _) => const SizedBox(
                    height: 200,
                    child: Center(
                      child: Text('Could not load bodyweight data'),
                    ),
                  ),
                  data: (weights) =>
                      BodyweightSparkline(entries: weights),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
