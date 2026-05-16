import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/algorithms/mifflin_st_jeor.dart';
import '../core/database/database.dart';
import 'bodyweight_provider.dart';
import 'goals_provider.dart';
import 'maintenance_provider.dart';

class MacroTargets {
  final double targetCalories;
  final double proteinGrams;
  final double fatGrams;
  final double carbsGrams;
  final double? maintenanceCalories;
  final double calorieAdjustment;
  final double rateLbsPerWeek;

  MacroTargets({
    required this.targetCalories,
    required this.proteinGrams,
    required this.fatGrams,
    required this.carbsGrams,
    this.maintenanceCalories,
    required this.calorieAdjustment,
    required this.rateLbsPerWeek,
  });

  factory MacroTargets.compute({
    required UserGoal? goals,
    required double? weightKg,
    required double? regressionMaintenance,
  }) {
    final adjustment = goals?.calorieAdjustment ?? 0;
    final rate = adjustment * 7 / 3500;

    double targetCalories;
    double? maintenanceCalories;

    if (regressionMaintenance != null) {
      targetCalories = regressionMaintenance + adjustment;
      maintenanceCalories = regressionMaintenance;
    } else if (goals?.onboardingCompleted == 1 &&
        goals?.sex != null &&
        goals?.heightCm != null &&
        goals?.birthdate != null &&
        weightKg != null) {
      final estimated = estimateMaintenance(
        sex: goals!.sex!,
        weightKg: weightKg,
        heightCm: goals.heightCm!,
        birthdate: goals.birthdate,
        activityLevel: goals.activityLevel,
      );
      targetCalories = estimated + adjustment;
      maintenanceCalories = estimated;
    } else {
      targetCalories = adjustment > 1200 ? adjustment : 1200;
    }

    final proteinGPerLb = goals?.proteinGPerLb ?? 1.0;
    final weightLb = weightKg != null ? weightKg * 2.20462 : 0.0;
    final proteinGrams = weightLb * proteinGPerLb;
    final proteinCal = proteinGrams * 4;

    final fatPct = (goals?.fatCaloriePct ?? 25.0) / 100;
    final fatCal = targetCalories * fatPct;
    final fatGrams = fatCal / 9;

    final carbsCal = targetCalories - proteinCal - fatCal;
    final carbsGrams = carbsCal / 4;

    return MacroTargets(
      targetCalories: targetCalories,
      proteinGrams: proteinGrams,
      fatGrams: fatGrams,
      carbsGrams: carbsGrams,
      maintenanceCalories: maintenanceCalories,
      calorieAdjustment: adjustment,
      rateLbsPerWeek: rate,
    );
  }
}

final macroTargetsProvider = FutureProvider<MacroTargets>((ref) async {
  final goals = await ref.watch(userGoalsProvider.future);
  final entries = await ref.watch(bodyweightProvider.future);
  final maintenanceResult = await ref.watch(maintenanceProvider.future);

  final weightKg = entries.isNotEmpty ? entries.first.weightKg : null;

  return MacroTargets.compute(
    goals: goals,
    weightKg: weightKg,
    regressionMaintenance: maintenanceResult?.maintenanceCalories,
  );
});
