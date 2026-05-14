# T7: Add recipe duplication

**Issue:** #5
**Effort:** ~20-30 min
**Dependencies:** Should follow or be paired with T6 (both touch `_RecipeCard` in `recipe_list_screen.dart`)

## Context

There is no way to duplicate a recipe in the app. Users must manually re-enter all ingredients and settings to create a variation of an existing recipe.

The data model supports duplication:
- `Recipes` table: `name`, `servingSize`, `servingLabel`, `createdAt`, `updatedAt`
- `RecipeIngredients` table: `recipeId`, `foodId`, `quantity`, `createdAt`
- `recipeDetailProvider` already returns `RecipeDetail` with full ingredient list (`List<IngredientWithFood>`)
- `db.insertRecipe()` and `db.insertIngredient()` already exist in `AppDatabase`
- `RecipeService` wraps both insert methods

## Intent

Allow users to duplicate a recipe with one tap, creating an independent copy with `"(Copy)"` appended to the name.

## Changes

### Option A: Add to `RecipeService` (recommended)

**File:** `lib/providers/recipe_provider.dart`

Add a `duplicateRecipe` method to `RecipeService`:

```dart
Future<int> duplicateRecipe(int recipeId) async {
  final detail = await db.getRecipeDetail(recipeId); // hypothetical getter, or inline the query
  if (detail == null) throw Exception('Recipe not found');
  
  // Could also accept: recipeDetailProvider.future passed in, or load inside here
  
  // Fetch recipe + ingredients
  final recipe = await db.getRecipe(recipeId);
  final ingredients = await db.getIngredientsWithFood(recipeId);
  if (recipe == null) throw Exception('Recipe not found');
  
  final now = DateTime.now().toIso8601String();
  
  // Insert new recipe with "(Copy)" suffix
  final newId = await db.insertRecipe(RecipesCompanion.insert(
    name: '${recipe.name} (Copy)',
    servingSize: recipe.servingSize,
    servingLabel: recipe.servingLabel,
    createdAt: now,
    updatedAt: now,
  ));
  
  // Re-insert all ingredients
  for (final item in ingredients) {
    await db.insertIngredient(RecipeIngredientsCompanion.insert(
      recipeId: newId,
      foodId: item.ingredient.foodId,
      quantity: item.ingredient.quantity,
      createdAt: now,
    ));
  }
  
  return newId;
}
```

Note: `AppDatabase` currently has no `getRecipeDetail` method. The duplication logic can inline the two queries (`getRecipe` + `getIngredientsWithFood`), which is what `recipeDetailProvider` does internally anyway.

### Option B: Inline in the screen handler

If extracting to `RecipeService` seems overengineered for a single callsite, the logic can live in the `_RecipeCard` handler in `recipe_list_screen.dart`.

### UI placement

Add a "Duplicate" action to the recipe card's overflow/popup menu (see T6). If T6 uses a `PopupMenuButton`, "Duplicate" is simply another entry in the menu.

Handler pseudocode:
```dart
Future<void> _duplicateRecipe(Recipe recipe) async {
  final db = ref.read(databaseProvider);
  final ingredients = await db.getIngredientsWithFood(recipe.id);
  final now = DateTime.now().toIso8601String();
  
  final newId = await db.insertRecipe(RecipesCompanion.insert(
    name: '${recipe.name} (Copy)',
    servingSize: recipe.servingSize,
    servingLabel: recipe.servingLabel,
    createdAt: now,
    updatedAt: now,
  ));
  
  for (final item in ingredients) {
    await db.insertIngredient(RecipeIngredientsCompanion.insert(
      recipeId: newId,
      foodId: item.ingredient.foodId,
      quantity: item.ingredient.quantity,
      createdAt: now,
    ));
  }
  
  ref.invalidate(recipeListProvider);
}
```

## Testing

- **Manual:** Open the Recipes tab. Duplicate a recipe with several ingredients. Verify a new recipe appears with `"(Copy)"` suffix. Open both the original and copy and verify they have identical ingredients (same food items, same quantities).
- **Widget test:** Create a recipe with 3 ingredients in an in-memory DB. Render `RecipeListScreen` in a `ProviderScope`. Trigger duplication via the popup menu. Verify `recipeListProvider` now returns 2 recipes. Verify the copied recipe has the same `servingSize`, `servingLabel`, and same number of ingredients with the same `foodId` and `quantity` values.
- **Unit test (if using RecipeService):** Test `duplicateRecipe` directly with an in-memory DB — insert recipe + ingredients, call `duplicateRecipe`, verify the new recipe's data.
