import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/database/database.dart';
import 'goals_provider.dart';
import 'reset_provider.dart';

class UnitPreferences {
  final bool useImperial;
  final double weightFactor;
  final String weightUnit;
  final double heightFactor;
  final String heightUnit;

  const UnitPreferences({
    required this.useImperial,
    required this.weightFactor,
    required this.weightUnit,
    required this.heightFactor,
    required this.heightUnit,
  });

  double displayWeight(double kg) => kg * weightFactor;
  double kgWeight(double display) => display / weightFactor;

  factory UnitPreferences.metric() => const UnitPreferences(
        useImperial: false,
        weightFactor: 1.0,
        weightUnit: 'kg',
        heightFactor: 1.0,
        heightUnit: 'cm',
      );

  factory UnitPreferences.imperial() => const UnitPreferences(
        useImperial: true,
        weightFactor: 2.20462,
        weightUnit: 'lb',
        heightFactor: 0.393701,
        heightUnit: 'ft/in',
      );

  factory UnitPreferences.fromGoals(UserGoal? goals) {
    return goals?.useImperial == 1
        ? UnitPreferences.imperial()
        : UnitPreferences.metric();
  }
}

final unitPreferencesProvider = Provider<UnitPreferences>((ref) {
  ref.watch(resetTriggerProvider);
  final goals = ref.watch(userGoalsProvider).valueOrNull;
  return UnitPreferences.fromGoals(goals);
});
