import 'package:drift/drift.dart';
import 'foods.dart';
import 'recipes.dart';

class FoodEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  RealColumn get calories => real()();
  RealColumn get proteinGrams => real()();
  RealColumn get carbsGrams => real()();
  RealColumn get fatGrams => real()();
  RealColumn get servings => real()();
  TextColumn get servingLabel => text()();
  TextColumn get barcode => text().nullable()();
  IntColumn get foodId => integer().nullable().references(Foods, #id)();
  IntColumn get recipeId => integer().nullable().references(Recipes, #id)();
  TextColumn get mealType => text()();
  TextColumn get loggedAt => text()();
}
