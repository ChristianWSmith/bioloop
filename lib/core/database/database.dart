import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';

import 'tables/foods.dart';
import 'tables/food_entries.dart';
import 'tables/bodyweight_entries.dart';
import 'tables/user_goals.dart';
import 'tables/recipes.dart';
import 'tables/recipe_ingredients.dart';

part 'database.g.dart';

@DriftDatabase(
  tables: [
    Foods,
    FoodEntries,
    BodyweightEntries,
    UserGoals,
    Recipes,
    RecipeIngredients,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (m) async {
        await m.createAll();
      },
    );
  }

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

  Future<Food?> getFoodById(int id) async {
    return await (select(foods)..where((f) => f.id.equals(id))).getSingleOrNull();
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

  Future<void> updateFoodById(int id, FoodsCompanion food) async {
    await (update(foods)..where((f) => f.id.equals(id))).write(food);
  }

  Future<void> deleteFood(int id) async {
    await transaction(() async {
      await (delete(foodEntries)..where((e) => e.foodId.equals(id))).go();
      await (delete(foods)..where((f) => f.id.equals(id))).go();
    });
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

  Future<List<({Food food, String lastUsed})>> getRecentFoods({int limit = 10}) async {
    final allEntries = await (select(foodEntries)
          ..where((f) => f.foodId.isNotNull())
          ..orderBy([
            (f) => OrderingTerm(expression: f.loggedAt, mode: OrderingMode.desc)
          ]))
        .get();

    final seenIds = <int>{};
    final recentIds = <int>[];
    final lastUsedMap = <int, String>{};
    for (final entry in allEntries) {
      if (entry.foodId != null && seenIds.add(entry.foodId!)) {
        recentIds.add(entry.foodId!);
        lastUsedMap[entry.foodId!] = entry.loggedAt;
        if (recentIds.length >= limit) break;
      }
    }

    if (recentIds.isEmpty) return [];

    final foodList = await (select(foods)
          ..where((f) => f.id.isIn(recentIds)))
        .get();

    final foodMap = {for (final f in foodList) f.id: f};

    return recentIds
        .map((id) => (
              food: foodMap[id]!,
              lastUsed: lastUsedMap[id]!,
            ))
        .toList();
  }

  Future<List<Food>> searchLocalByRecency({String? query, int limit = 50}) async {
    final allEntries = await (select(foodEntries)
          ..where((f) => f.foodId.isNotNull())
          ..orderBy([
            (f) => OrderingTerm(expression: f.loggedAt, mode: OrderingMode.desc)
          ]))
        .get();

    final seenIds = <int>{};
    final orderedIds = <int>[];
    for (final entry in allEntries) {
      if (entry.foodId != null && seenIds.add(entry.foodId!)) {
        orderedIds.add(entry.foodId!);
      }
    }

    final allFoods = await (select(foods).get());
    final rest = allFoods.where((f) => !seenIds.contains(f.id)).toList();
    rest.sort((a, b) => a.name.compareTo(b.name));

    final foodMap = {for (final f in allFoods) f.id: f};
    final orderedFoods = orderedIds
        .map((id) => foodMap[id])
        .whereType<Food>()
        .toList();

    final combined = [...orderedFoods, ...rest];

    if (query != null && query.trim().isNotEmpty) {
      final q = query.toLowerCase();
      return combined
          .where((f) => f.name.toLowerCase().contains(q))
          .take(limit)
          .toList();
    }

    return combined.take(limit).toList();
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

  // ── Recipes DAO ─────────────────────────────────────────────

  Future<int> insertRecipe(RecipesCompanion recipe) async {
    return await into(recipes).insert(recipe);
  }

  Future<Recipe?> getRecipe(int id) async {
    return await (select(recipes)..where((r) => r.id.equals(id)))
        .getSingleOrNull();
  }

  Future<List<Recipe>> getAllRecipes() async {
    return await (select(recipes)
          ..orderBy([
            (r) => OrderingTerm(expression: r.name, mode: OrderingMode.asc)
          ]))
        .get();
  }

  Future<void> updateRecipe(int id, RecipesCompanion recipe) async {
    await (update(recipes)..where((r) => r.id.equals(id))).write(recipe);
  }

  Future<void> deleteRecipe(int id) async {
    await (delete(recipes)..where((r) => r.id.equals(id))).go();
  }

  Future<Recipe> duplicateRecipe(int recipeId) async {
    final original = await getRecipe(recipeId);
    if (original == null) throw Exception('Recipe not found');

    final ingredients = await getIngredientsWithFood(recipeId);
    final now = DateTime.now().toIso8601String();
    final newName = '${original.name} (copy)';

    final newId = await insertRecipe(RecipesCompanion.insert(
      name: newName,
      servingSize: original.servingSize,
      servingLabel: original.servingLabel,
      createdAt: now,
      updatedAt: now,
    ));

    for (final item in ingredients) {
      await insertIngredient(RecipeIngredientsCompanion.insert(
        recipeId: newId,
        foodId: item.food.id,
        quantity: item.ingredient.quantity,
        createdAt: now,
      ));
    }

    return Recipe(
      id: newId,
      name: newName,
      servingSize: original.servingSize,
      servingLabel: original.servingLabel,
      createdAt: now,
      updatedAt: now,
    );
  }

  // ── Recipe Ingredients DAO ──────────────────────────────────

  Future<int> insertIngredient(RecipeIngredientsCompanion ingredient) async {
    return await into(recipeIngredients).insert(ingredient);
  }

  Future<List<IngredientWithFood>> getIngredientsWithFood(int recipeId) async {
    final query = select(recipeIngredients).join([
      innerJoin(foods, foods.id.equalsExp(recipeIngredients.foodId)),
    ]);
    query.where(recipeIngredients.recipeId.equals(recipeId));
    final rows = await query.get();

    return rows.map((row) {
      return IngredientWithFood(
        ingredient: row.readTable(recipeIngredients),
        food: row.readTable(foods),
      );
    }).toList();
  }

  Future<void> updateIngredient(RecipeIngredientsCompanion ingredient, int id) async {
    await (update(recipeIngredients)..where((i) => i.id.equals(id)))
        .write(ingredient);
  }

  Future<void> deleteIngredient(int id) async {
    await (delete(recipeIngredients)..where((i) => i.id.equals(id))).go();
  }

  Future<void> deleteIngredientsForRecipe(int recipeId) async {
    await (delete(recipeIngredients)..where((i) => i.recipeId.equals(recipeId)))
        .go();
  }

  Future<RecipeMacros> computeRecipeMacros(int recipeId) async {
    final recipe = await getRecipe(recipeId);
    if (recipe == null) {
      return RecipeMacros(
        calories: 0,
        proteinGrams: 0,
        carbsGrams: 0,
        fatGrams: 0,
        perUnitCalories: 0,
        perUnitProtein: 0,
        perUnitCarbs: 0,
        perUnitFat: 0,
      );
    }

    final ingredients = await getIngredientsWithFood(recipeId);
    double totalCals = 0, totalProtein = 0, totalCarbs = 0, totalFat = 0;

    for (final item in ingredients) {
      final qty = item.ingredient.quantity;
      final sq = item.food.servingQuantity > 0 ? item.food.servingQuantity : 1;
      totalCals += item.food.caloriesPerServing * (qty / sq);
      totalProtein += item.food.proteinPerServing * (qty / sq);
      totalCarbs += item.food.carbsPerServing * (qty / sq);
      totalFat += item.food.fatPerServing * (qty / sq);
    }

    final perUnit = recipe.servingSize > 0 ? recipe.servingSize : 1;
    return RecipeMacros(
      calories: totalCals,
      proteinGrams: totalProtein,
      carbsGrams: totalCarbs,
      fatGrams: totalFat,
      perUnitCalories: totalCals / perUnit,
      perUnitProtein: totalProtein / perUnit,
      perUnitCarbs: totalCarbs / perUnit,
      perUnitFat: totalFat / perUnit,
    );
  }

  // ── Data Reset ──────────────────────────────────────────────

  Future<void> resetAll() async {
    await transaction(() async {
      await delete(recipeIngredients).go();
      await delete(foodEntries).go();
      await delete(recipes).go();
      await delete(bodyweightEntries).go();
      await delete(userGoals).go();
      await delete(foods).go();
    });
  }
}

class IngredientWithFood {
  final RecipeIngredient ingredient;
  final Food food;
  const IngredientWithFood({required this.ingredient, required this.food});
}

class RecipeMacros {
  final double calories;
  final double proteinGrams;
  final double carbsGrams;
  final double fatGrams;
  final double perUnitCalories;
  final double perUnitProtein;
  final double perUnitCarbs;
  final double perUnitFat;

  const RecipeMacros({
    required this.calories,
    required this.proteinGrams,
    required this.carbsGrams,
    required this.fatGrams,
    required this.perUnitCalories,
    required this.perUnitProtein,
    required this.perUnitCarbs,
    required this.perUnitFat,
  });
}
