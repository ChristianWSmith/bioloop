import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/database/database.dart';
import 'database_provider.dart';

final recipeListProvider = FutureProvider<List<Recipe>>((ref) async {
  final db = ref.read(databaseProvider);
  return await db.getAllRecipes();
});

final recipeDetailProvider = FutureProvider.family<RecipeDetail?, int>((ref, id) async {
  final db = ref.read(databaseProvider);
  final recipe = await db.getRecipe(id);
  if (recipe == null) return null;
  final ingredients = await db.getIngredientsWithFood(id);
  final macros = await db.computeRecipeMacros(id);
  return RecipeDetail(recipe: recipe, ingredients: ingredients, macros: macros);
});

class RecipeService {
  final AppDatabase db;
  RecipeService({required this.db});

  Future<int> insertRecipe(RecipesCompanion recipe) => db.insertRecipe(recipe);

  Future<int> insertIngredient(RecipeIngredientsCompanion ingredient) =>
      db.insertIngredient(ingredient);

  Future<void> updateRecipe(int id, RecipesCompanion recipe) =>
      db.updateRecipe(id, recipe);

  Future<void> deleteRecipe(int id) => db.deleteRecipe(id);

  Future<void> deleteIngredientsForRecipe(int recipeId) =>
      db.deleteIngredientsForRecipe(recipeId);

  Future<RecipeMacros> computeRecipeMacros(int recipeId) =>
      db.computeRecipeMacros(recipeId);

  Future<List<IngredientWithFood>> getIngredientsWithFood(int recipeId) =>
      db.getIngredientsWithFood(recipeId);

  Future<int> logRecipe({
    required int recipeId,
    required double portion,
    required String mealType,
    DateTime? loggedAt,
  }) async {
    final recipe = await db.getRecipe(recipeId);
    if (recipe == null) throw Exception('Recipe not found');
    final macros = await db.computeRecipeMacros(recipeId);
    final scale = recipe.servingSize > 0 ? portion / recipe.servingSize : 1.0;
    final now = (loggedAt ?? DateTime.now()).toIso8601String();

    return await db.insertEntry(FoodEntriesCompanion.insert(
      name: recipe.name,
      calories: macros.calories * scale,
      proteinGrams: macros.proteinGrams * scale,
      carbsGrams: macros.carbsGrams * scale,
      fatGrams: macros.fatGrams * scale,
      servings: scale,
      servingLabel: recipe.servingLabel,
      recipeId: Value(recipeId),
      mealType: mealType,
      loggedAt: now,
    ));
  }
}

final recipeServiceProvider = Provider<RecipeService>((ref) {
  return RecipeService(db: ref.read(databaseProvider));
});

class RecipeDetail {
  final Recipe recipe;
  final List<IngredientWithFood> ingredients;
  final RecipeMacros macros;

  const RecipeDetail({
    required this.recipe,
    required this.ingredients,
    required this.macros,
  });
}
