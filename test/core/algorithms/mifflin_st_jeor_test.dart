import 'package:flutter_test/flutter_test.dart';
import 'package:bioloop/core/algorithms/mifflin_st_jeor.dart';

void main() {
  group('ageFromBirthdate', () {
    test('returns 30 for 1996-01-01', () {
      expect(ageFromBirthdate('1996-01-01'), 30);
    });

    test('returns 25 for 2001-01-01', () {
      expect(ageFromBirthdate('2001-01-01'), 25);
    });

    test('returns 0 for today', () {
      final now = DateTime.now();
      final today =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      expect(ageFromBirthdate(today), 0);
    });

    test('returns default 30 for null', () {
      expect(ageFromBirthdate(null), 30);
    });

    test('returns default 30 for invalid date', () {
      expect(ageFromBirthdate('not-a-date'), 30);
    });
  });

  group('Mifflin-St Jeor', () {
    test('male default (moderate) — 80kg, 178cm, birthdate 1996-01-01', () {
      final result = estimateMaintenance(
        sex: 'male',
        weightKg: 80,
        heightCm: 178,
        birthdate: '1996-01-01',
      );
      // BMR = 10×80 + 6.25×178 − 5×30 + 5 = 1767.5
      // TDEE = 1767.5 × 1.55 = 2739.625
      expect(result, closeTo(2739.6, 2.8));
    });

    test('female default (moderate) — 80kg, 178cm, birthdate 1996-01-01', () {
      final result = estimateMaintenance(
        sex: 'female',
        weightKg: 80,
        heightCm: 178,
        birthdate: '1996-01-01',
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
        birthdate: '1996-01-01',
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
        birthdate: '1996-01-01',
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
        birthdate: '1996-01-01',
        activityLevel: 0,
      );
      final clampedHigh = estimateMaintenance(
        sex: 'male',
        weightKg: 80,
        heightCm: 178,
        birthdate: '1996-01-01',
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
        birthdate: '1996-01-01',
      );
      final heavier = estimateMaintenance(
        sex: 'male',
        weightKg: 80,
        heightCm: 178,
        birthdate: '1996-01-01',
      );
      expect(lighter, lessThan(heavier));
    });

    test('height changes — 160cm produces lower result than 178cm', () {
      final shorter = estimateMaintenance(
        sex: 'male',
        weightKg: 80,
        heightCm: 160,
        birthdate: '1996-01-01',
      );
      final taller = estimateMaintenance(
        sex: 'male',
        weightKg: 80,
        heightCm: 178,
        birthdate: '1996-01-01',
      );
      expect(shorter, lessThan(taller));
    });
  });
}
