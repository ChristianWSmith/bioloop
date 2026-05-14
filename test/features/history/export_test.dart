import 'package:bioloop/features/history/export.dart';
import 'package:bioloop/core/database/database.dart';
import 'package:flutter_test/flutter_test.dart';

FoodEntry _makeEntry({
  int id = 1,
  String name = 'Chicken Breast',
  double calories = 165,
  double proteinGrams = 31,
  double carbsGrams = 0,
  double fatGrams = 3.6,
  double servings = 1,
  String servingLabel = '100g',
  String mealType = 'lunch',
  String date = '2026-05-12',
}) {
  return FoodEntry(
    id: id,
    name: name,
    calories: calories,
    proteinGrams: proteinGrams,
    carbsGrams: carbsGrams,
    fatGrams: fatGrams,
    servings: servings,
    servingLabel: servingLabel,
    mealType: mealType,
    loggedAt: '${date}T12:00:00',
  );
}

BodyweightEntry _makeWeight({
  int id = 1,
  double weightKg = 75,
  String date = '2026-05-12',
}) {
  return BodyweightEntry(
    id: id,
    weightKg: weightKg,
    loggedAt: '${date}T08:00:00',
  );
}

void main() {
  group('exportFoodEntriesToCsv', () {
    test('produces header + data rows for 3 entries', () {
      final entries = [
        _makeEntry(name: 'Oats', date: '2026-05-10'),
        _makeEntry(name: 'Chicken', date: '2026-05-11'),
        _makeEntry(name: 'Rice', date: '2026-05-12'),
      ];

      final csv = exportFoodEntriesToCsv(entries);
      final lines = csv.trim().split('\n');

      expect(lines.length, 4);
      expect(lines[0], 'date,meal_type,name,servings,calories,protein_g,carbs_g,fat_g');
      expect(lines[1], '2026-05-10,lunch,Oats,1.0,165,31.0,0.0,3.6');
      expect(lines[2], '2026-05-11,lunch,Chicken,1.0,165,31.0,0.0,3.6');
      expect(lines[3], '2026-05-12,lunch,Rice,1.0,165,31.0,0.0,3.6');
    });

    test('empty entries produces header only', () {
      final csv = exportFoodEntriesToCsv([]);
      expect(csv.trim(), 'date,meal_type,name,servings,calories,protein_g,carbs_g,fat_g');
    });

    test('food name with commas is quoted', () {
      final entries = [
        _makeEntry(name: 'Oats, Old-Fashioned', date: '2026-05-12'),
      ];

      final csv = exportFoodEntriesToCsv(entries);
      final lines = csv.trim().split('\n');

      expect(lines.length, 2);
      expect(lines[1], '2026-05-12,lunch,"Oats, Old-Fashioned",1.0,165,31.0,0.0,3.6');
    });

    test('food name with double quotes is escaped', () {
      final entries = [
        _makeEntry(name: 'Chicken "Breast"', date: '2026-05-12'),
      ];

      final csv = exportFoodEntriesToCsv(entries);
      final lines = csv.trim().split('\n');

      expect(lines[1], '2026-05-12,lunch,"Chicken ""Breast""",1.0,165,31.0,0.0,3.6');
    });

    test('all field types render correctly', () {
      final entries = [
        _makeEntry(
          name: 'Test Food',
          calories: 250.5,
          proteinGrams: 20.3,
          carbsGrams: 30.7,
          fatGrams: 8.2,
          servings: 2.5,
          mealType: 'breakfast',
          date: '2026-05-12',
        ),
      ];

      final csv = exportFoodEntriesToCsv(entries);
      final lines = csv.trim().split('\n');
      // All macros should have 1 decimal place
      expect(lines[1], '2026-05-12,breakfast,Test Food,2.5,250,20.3,30.7,8.2');
    });
  });

  group('exportBodyweightToCsv', () {
    test('produces header + data rows for 2 entries', () {
      final entries = [
        _makeWeight(weightKg: 75, date: '2026-05-10'),
        _makeWeight(weightKg: 74.5, date: '2026-05-12'),
      ];

      final csv = exportBodyweightToCsv(entries, weightUnit: 'kg');
      final lines = csv.trim().split('\n');

      expect(lines.length, 3);
      expect(lines[0], 'date,weight,kg');
      expect(lines[1], '2026-05-10,75.0,kg');
      expect(lines[2], '2026-05-12,74.5,kg');
    });

    test('produces header + data rows for 2 entries in imperial', () {
      final entries = [
        _makeWeight(weightKg: 75, date: '2026-05-10'),
        _makeWeight(weightKg: 74.5, date: '2026-05-12'),
      ];

      final csv = exportBodyweightToCsv(entries, weightUnit: 'lb');
      final lines = csv.trim().split('\n');

      expect(lines.length, 3);
      expect(lines[0], 'date,weight,lb');
      expect(lines[1], '2026-05-10,${(75 * 2.20462).toStringAsFixed(1)},lb');
      expect(lines[2], '2026-05-12,${(74.5 * 2.20462).toStringAsFixed(1)},lb');
    });

    test('empty entries produces header only', () {
      final csv = exportBodyweightToCsv([], weightUnit: 'kg');
      expect(csv.trim(), 'date,weight,kg');
    });
  });
}
