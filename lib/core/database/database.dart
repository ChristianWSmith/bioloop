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

  Future<void> updateWeight(BodyweightEntry entry) async {
    await (update(bodyweightEntries)..where((b) => b.id.equals(entry.id)))
        .write(BodyweightEntriesCompanion(
      weightKg: Value(entry.weightKg),
      loggedAt: Value(entry.loggedAt),
    ));
  }

  Future<int> deleteWeight(int id) async {
    return await (delete(bodyweightEntries)..where((b) => b.id.equals(id)))
        .go();
  }

  Future<List<BodyweightEntry>> getWeights({int? limit, DateTime? since}) async {
    var results = await (select(bodyweightEntries)
          ..orderBy([
            (b) =>
                OrderingTerm(expression: b.loggedAt, mode: OrderingMode.desc)
          ]))
        .get();
    if (since != null) {
      final sinceStr =
          '${since.year}-${since.month.toString().padLeft(2, '0')}-${since.day.toString().padLeft(2, '0')}';
      results = results.where((e) => e.loggedAt.compareTo(sinceStr) >= 0).toList();
    }
    if (limit != null) {
      results = results.take(limit).toList();
    }
    return results;
  }

  // ── Foods DAO ───────────────────────────────────────────────

  Future<int> insertFood(FoodsCompanion food) async {
    return await into(foods).insert(food);
  }

  Future<Food?> getByBarcode(String barcode) async {
    return await (select(foods)..where((f) => f.barcode.equals(barcode)))
        .getSingleOrNull();
  }

  Future<List<Food>> searchByName(String query, {int limit = 25}) async {
    return await (select(foods)
          ..where((f) => f.name.like('%$query%'))
          ..limit(limit))
        .get();
  }

  Future<void> upsertFood(FoodsCompanion food) async {
    final barcode = food.barcode.value;
    if (barcode != null) {
      final existing = await getByBarcode(barcode);
      if (existing != null) {
        await (update(foods)..where((f) => f.barcode.equals(barcode)))
            .write(food);
        return;
      }
    }
    await into(foods).insert(food);
  }

  // ── Food Entries DAO ──────────────────────────────────────────

  Future<int> insertEntry(FoodEntriesCompanion entry) async {
    return await into(foodEntries).insert(entry);
  }

  Future<List<FoodEntry>> getEntriesForDate(DateTime date) async {
    final dateStr =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    return await (select(foodEntries)
          ..where((f) => f.loggedAt.like('$dateStr%'))
          ..orderBy([
            (f) => OrderingTerm(expression: f.loggedAt, mode: OrderingMode.desc)
          ]))
        .get();
  }

  Future<int> deleteEntry(int id) async {
    return await (delete(foodEntries)..where((f) => f.id.equals(id))).go();
  }

  Future<List<FoodEntry>> getEntriesPaginated(
      {int offset = 0, int limit = 20}) async {
    return await (select(foodEntries)
          ..orderBy([
            (f) =>
                OrderingTerm(expression: f.loggedAt, mode: OrderingMode.desc)
          ])
          ..limit(limit, offset: offset))
        .get();
  }

  Future<void> updateEntry(FoodEntry entry) async {
    await (update(foodEntries)..where((f) => f.id.equals(entry.id)))
        .write(FoodEntriesCompanion(
      name: Value(entry.name),
      servings: Value(entry.servings),
      calories: Value(entry.calories),
      proteinGrams: Value(entry.proteinGrams),
      carbsGrams: Value(entry.carbsGrams),
      fatGrams: Value(entry.fatGrams),
      mealType: Value(entry.mealType),
    ));
  }
}
