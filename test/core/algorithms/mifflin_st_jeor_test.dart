import 'package:flutter_test/flutter_test.dart';
import 'package:bioloop/core/algorithms/mifflin_st_jeor.dart';

void main() {
  group('Mifflin-St Jeor', () {
    test('male default (moderate) — 80kg, 178cm, 30y', () {
      final result = estimateMaintenance(
        sex: 'male',
        weightKg: 80,
        heightCm: 178,
        age: 30,
      );
      // BMR = 10×80 + 6.25×178 − 5×30 + 5 = 1767.5
      // TDEE = 1767.5 × 1.55 = 2739.625
      expect(result, closeTo(2739.6, 2.8));
    });

    test('female default (moderate) — 80kg, 178cm, 30y', () {
      final result = estimateMaintenance(
        sex: 'female',
        weightKg: 80,
        heightCm: 178,
        age: 30,
      );
      // BMR = 10×80 + 6.25×178 − 5×30 − 161 = 1601.5
      // TDEE = 1601.5 × 1.55 = 2482.325
      expect(result, closeTo(2482.3, 2.5));
    });

    test('sedentary — activityLevel=1 gives lower result than default', () {
      final result = estimateMaintenance(
        sex: 'male',
        weightKg: 80,
        heightCm: 178,
        age: 30,
        activityLevel: 1,
      );
      // 1767.5 × 1.2 = 2121.0
      expect(result, closeTo(2121.0, 2.2));
    });

    test('extra active — activityLevel=5 gives higher result than default', () {
      final result = estimateMaintenance(
        sex: 'male',
        weightKg: 80,
        heightCm: 178,
        age: 30,
        activityLevel: 5,
      );
      // 1767.5 × 1.9 = 3358.25
      expect(result, closeTo(3358.3, 3.4));
    });

    test('activity level clamping — 0 clamps to 1, 7 clamps to 5', () {
      final clampedLow = estimateMaintenance(
        sex: 'male',
        weightKg: 80,
        heightCm: 178,
        age: 30,
        activityLevel: 0,
      );
      final clampedHigh = estimateMaintenance(
        sex: 'male',
        weightKg: 80,
        heightCm: 178,
        age: 30,
        activityLevel: 7,
      );
      expect(clampedLow, closeTo(2121.0, 2.2));
      expect(clampedHigh, closeTo(3358.3, 3.4));
    });

    test('weight changes — 70kg produces lower result than 80kg', () {
      final lighter = estimateMaintenance(
        sex: 'male',
        weightKg: 70,
        heightCm: 178,
        age: 30,
      );
      final heavier = estimateMaintenance(
        sex: 'male',
        weightKg: 80,
        heightCm: 178,
        age: 30,
      );
      expect(lighter, lessThan(heavier));
    });

    test('height changes — 160cm produces lower result than 178cm', () {
      final shorter = estimateMaintenance(
        sex: 'male',
        weightKg: 80,
        heightCm: 160,
        age: 30,
      );
      final taller = estimateMaintenance(
        sex: 'male',
        weightKg: 80,
        heightCm: 178,
        age: 30,
      );
      expect(shorter, lessThan(taller));
    });
  });
}
