import 'dart:math';

/// Clamps a food's calorie value to the maximum possible based on its macros
/// using the 4-4-9 rule (protein=4, carbs=4, fat=9 cal/g).
///
/// Allows calories to be less than the macro maximum (e.g. sugar alcohols),
/// but never more. Returns a value >= 0.
double clampCaloriesToMacros({
  required double calories,
  required double protein,
  required double carbs,
  required double fat,
}) {
  final macroCalories = protein * 4 + carbs * 4 + fat * 9;
  return max(0.0, min(calories, macroCalories));
}
