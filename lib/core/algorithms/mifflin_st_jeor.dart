const List<double> _activityMultipliers = [1.2, 1.375, 1.55, 1.725, 1.9];

int ageFromBirthdate(String? birthdate) {
  if (birthdate == null) return 30;
  final date = DateTime.tryParse(birthdate);
  if (date == null) return 30;
  final now = DateTime.now();
  int age = now.year - date.year;
  if (now.month < date.month ||
      (now.month == date.month && now.day < date.day)) {
    age--;
  }
  return age;
}

double estimateMaintenance({
  required String sex,
  required double weightKg,
  required double heightCm,
  required String? birthdate,
  int activityLevel = 3,
}) {
  final age = ageFromBirthdate(birthdate);
  final clamped = activityLevel.clamp(1, 5);
  final double bmr;
  if (sex == 'male') {
    bmr = 10 * weightKg + 6.25 * heightCm - 5 * age + 5;
  } else {
    bmr = 10 * weightKg + 6.25 * heightCm - 5 * age - 161;
  }
  return bmr * _activityMultipliers[clamped - 1];
}
