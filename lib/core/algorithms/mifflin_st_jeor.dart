const List<double> _activityMultipliers = [1.2, 1.375, 1.55, 1.725, 1.9];

double estimateMaintenance({
  required String sex,
  required double weightKg,
  required double heightCm,
  required int age,
  int activityLevel = 3,
}) {
  final clamped = activityLevel.clamp(1, 5);
  final double bmr;
  if (sex == 'male') {
    bmr = 10 * weightKg + 6.25 * heightCm - 5 * age + 5;
  } else {
    bmr = 10 * weightKg + 6.25 * heightCm - 5 * age - 161;
  }
  return bmr * _activityMultipliers[clamped - 1];
}
