import 'package:drift/drift.dart';
import 'recipes.dart';
import 'foods.dart';

class RecipeIngredients extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get recipeId => integer().references(Recipes, #id)();
  IntColumn get foodId => integer().references(Foods, #id)();
  RealColumn get quantity => real()();
  TextColumn get createdAt => text()();
}
