import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';

import 'tables/foods.dart';
import 'tables/food_entries.dart';
import 'tables/bodyweight_entries.dart';
import 'tables/user_goals.dart';
import 'tables/meal_templates.dart';
import 'tables/recipes.dart';
import 'tables/recipe_ingredients.dart';

part 'database.g.dart';

@DriftDatabase(
  tables: [
    Foods,
    FoodEntries,
    BodyweightEntries,
    UserGoals,
    MealTemplates,
    Recipes,
    RecipeIngredients,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 1;

  static Future<AppDatabase> create() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/bioloop.db');
    return AppDatabase(NativeDatabase(file));
  }

  static AppDatabase createInMemory() {
    return AppDatabase(NativeDatabase.memory());
  }

  // ── User Goals DAO ──────────────────────────────────────────

  Future<UserGoal?> getGoals() {
    return (select(userGoals)..where((g) => g.id.equals(1))).getSingleOrNull();
  }

  Future<void> upsertGoals(UserGoalsCompanion goals) async {
    final existing = await getGoals();
    if (existing != null) {
      await (update(userGoals)..where((g) => g.id.equals(1))).write(goals);
    } else {
      await into(userGoals).insert(goals);
    }
  }

  // ── Bodyweight DAO ──────────────────────────────────────────

  Future<int> insertWeight(BodyweightEntriesCompanion entry) async {
    return await into(bodyweightEntries).insert(entry);
  }
}
