import 'package:flutter_test/flutter_test.dart';
import 'package:bioloop/core/utils/calorie_clamp.dart';

void main() {
  group('clampCaloriesToMacros', () {
    test('clamps over-inflated calories to macro maximum', () {
      final result = clampCaloriesToMacros(
        calories: 170,
        protein: 1,
        carbs: 10,
        fat: 0,
      );
      expect(result, 44);
    });

    test('preserves calories below macro maximum (sugar alcohols)', () {
      final result = clampCaloriesToMacros(
        calories: 50,
        protein: 0,
        carbs: 20,
        fat: 0,
      );
      expect(result, 50);
    });

    test('clamps to macro maximum when calories match exactly', () {
      final result = clampCaloriesToMacros(
        calories: 200,
        protein: 10,
        carbs: 20,
        fat: 8,
      );
      expect(result, 192);
    });

    test('clamps zero macros with non-zero calories to 0', () {
      final result = clampCaloriesToMacros(
        calories: 100,
        protein: 0,
        carbs: 0,
        fat: 0,
      );
      expect(result, 0);
    });

    test('returns 0 for all-zero input', () {
      final result = clampCaloriesToMacros(
        calories: 0,
        protein: 0,
        carbs: 0,
        fat: 0,
      );
      expect(result, 0);
    });

    test('clamps negative calories to 0', () {
      final result = clampCaloriesToMacros(
        calories: -10,
        protein: 0,
        carbs: 0,
        fat: 0,
      );
      expect(result, 0);
    });

    test('handles typical food with accurate calories', () {
      final result = clampCaloriesToMacros(
        calories: 250,
        protein: 20,
        carbs: 30,
        fat: 5,
      );
      expect(result, 245);
    });

    test('handles high-fat food correctly', () {
      final result = clampCaloriesToMacros(
        calories: 500,
        protein: 5,
        carbs: 2,
        fat: 50,
      );
      expect(result, 478);
    });
  });
}
