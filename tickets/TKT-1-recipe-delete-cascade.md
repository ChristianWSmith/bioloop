# TKT-1: Fix recipe delete cascade

**Risk**: Low | **Files**: 1 | **Est**: <15min

---

## Context

Deleting a recipe via long-press or the trash icon calls `db.deleteRecipe(recipe.id)` which only deletes the `recipes` row. It does **not** cascade-delete `recipe_ingredients` rows, creating orphan records.

The confirmation dialog at `recipe_list_screen.dart:131` promises: `'Delete "${recipe.name}" and all its ingredients?'` — but the ingredients are never cleaned up. The `deleteIngredientsForRecipe()` method already exists at `database.dart:378` and is used during recipe save/update, but not during deletion.

## Findings

**File**: `lib/features/recipes/recipe_list_screen.dart:145-149`
```dart
if (confirmed == true) {
  final db = ref.read(databaseProvider);
  await db.deleteRecipe(recipe.id);  // <-- missing: deleteIngredientsForRecipe()
  ref.invalidate(recipeListProvider);
}
```

**Available method** at `database.dart:378`:
```dart
Future<void> deleteIngredientsForRecipe(int recipeId) async {
  await (delete(recipeIngredients)..where((i) => i.recipeId.equals(recipeId))).go();
}
```

## Acceptance Criteria

- Deleting a recipe via long-press cascades to all its ingredient rows
- Deleting a recipe via the trash icon cascades to all its ingredient rows
- The confirmation dialog accurately reflects what happens
- `deleteRecipe()` in the DAO layer (`database.dart`) cleans up ingredients (either directly or via caller)

## Implementation

In `recipe_list_screen.dart:146-148`, add the cascade before `deleteRecipe`:

```dart
if (confirmed == true) {
  final db = ref.read(databaseProvider);
  await db.deleteIngredientsForRecipe(recipe.id);
  await db.deleteRecipe(recipe.id);
  ref.invalidate(recipeListProvider);
}
```

## Testing

- **No new tests needed** — the existing `deleteRecipe` DAO test should verify the call works. The cascade fix is at the call site in the screen layer.
- To verify manually: create a recipe with ingredients, delete it, then inspect the DB (`recipe_ingredients` table should have no orphan rows for the deleted recipe).
- After implementation, run `flutter analyze` to confirm zero issues.
