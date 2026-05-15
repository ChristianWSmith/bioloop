# Ticket 05 — Polish recipe UX

**Issues**: #2 (ingredient display), #4 (edit discoverability), #5 (duplicate)  
**Phase**: 1  
**Dependencies**: None  
**Estimate**: ~1.5 hours

---

## Context

Three small recipe improvements in one ticket:

1. **Ingredient display formatting** — The ingredient row shows
   `"100.0 × 100g — 370 kcal"` for per-100g foods. Should be `"100g — 370 kcal"`
   when quantity matches servingQuantity. Clean up decimal formatting generally.

2. **Edit discoverability** — Tapping a recipe card opens edit mode, but
   there's no visual cue. Add an explicit edit icon button.

3. **Duplicate recipe** — No way to clone an existing recipe. Users want to
   create variations of recipes (e.g. "Chicken Salad" → "Chicken Salad with
   Avocado").

---

## Acceptance Criteria

### Ingredient display
- When `ingredient.quantity == food.servingQuantity`, show just
  `food.servingLabel` (e.g. `"100g — 370 kcal"`)
- Otherwise, show `"quantity g — XXX kcal"` using the `servingUnit`
- No "X.00" formatting — clean up decimals: `100` not `100.0`, `2.5` not `2.50`

### Edit icon
- Recipe cards in non-picker mode show an edit icon button (`Icons.edit`)
  alongside the existing delete icon

### Duplicate recipe
- Recipe cards in non-picker mode show a duplicate icon (`Icons.copy`) or
  a 3-dot popup menu with "Duplicate" option
- Duplicating creates a new recipe named `"<original> (copy)"` with identical
  serving size/label and all ingredients copied
- The user is navigated to edit mode for the new copy
- `recipeListProvider` is invalidated so the new recipe appears in the list

---

## Implementation

### 5a. Ingredient display formatting
**File**: `lib/features/recipes/widgets/recipe_ingredient_row.dart`

Replace line 27:
```dart
// Was:
'${ingredient.quantity.toStringAsFixed(1)} × ${food.servingLabel} — ${cals.toStringAsFixed(0)} kcal',

// New logic:
final qtyStr = ingredient.quantity == ingredient.quantity.roundToDouble()
    ? ingredient.quantity.toInt().toString()
    : ingredient.quantity.toStringAsFixed(1);
final displayText = ingredient.quantity == food.servingQuantity
    ? food.servingLabel
    : '$qtyStr ${food.servingUnit}';
'$displayText — ${cals.toStringAsFixed(0)} kcal',
```

### 5b. Edit icon button
**File**: `lib/features/recipes/recipe_list_screen.dart`

In `_RecipeCard.build()`, add an edit `IconButton` in the `trailing` row
before the delete button:
```dart
trailing: pickerMode
    ? const Icon(Icons.chevron_right)
    : Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit, size: 20),
            onPressed: onTap,
            tooltip: 'Edit recipe',
          ),
          IconButton(
            icon: const Icon(Icons.copy, size: 20),
            onPressed: onDuplicate,
            tooltip: 'Duplicate recipe',
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20),
            onPressed: onDelete,
            tooltip: 'Delete recipe',
          ),
        ],
      ),
```

Add `onDuplicate` callback to `_RecipeCard` and `_RecipeListScreen`.

### 5c. Duplicate recipe DAO
**File**: `lib/core/database/database.dart`

Add method:
```dart
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
```

### 5d. Wire up in RecipeListScreen
In `_openRecipe`, after duplicating, navigate to edit mode for the new recipe:
```dart
Future<void> _duplicateRecipe(Recipe recipe) async {
  final db = ref.read(databaseProvider);
  final newRecipe = await db.duplicateRecipe(recipe.id);
  ref.invalidate(recipeListProvider);
  if (!context.mounted) return;
  await Navigator.of(context).push<bool>(
    MaterialPageRoute(
      builder: (_) => RecipeFormScreen(recipeId: newRecipe.id),
    ),
  );
  ref.invalidate(recipeListProvider);
}
```

---

## Testing

### Unit tests (`test/features/recipes/recipes_test.dart`)

- **Add test**: `duplicateRecipe` creates new recipe with "(copy)" suffix
- **Add test**: duplicated recipe has identical serving size/label
- **Add test**: duplicated recipe has identical number of ingredients
- **Add test**: modifying the copy does not affect the original

### Widget tests

- **Update**: "edit mode shows recipe data" — also verify edit icon exists
- **Add test**: duplicate icon appears on recipe cards
- **Add test**: tapping duplicate icon navigates to edit mode
- **Add test**: ingredient display shows clean formatting (especially per-100g)

### Manual tests
- Create recipe "Chicken Salad" with ingredients
- **Verify**: ingredient shows "100g — 165 kcal" (not "100.0 × 100g — 165 kcal")
- **Verify**: ingredient row has edit/delete buttons
- Tap the duplicate icon
- **Verify**: a new recipe "Chicken Salad (copy)" appears in the list
- Open the copy
- **Verify**: all ingredients are present with correct quantities
- Modify the copy, save
- **Verify**: original is unchanged

---

## Files Changed

| File | Change |
|------|--------|
| `lib/features/recipes/widgets/recipe_ingredient_row.dart` | Clean up display formatting |
| `lib/features/recipes/recipe_list_screen.dart` | Add edit + duplicate icons, wire up |
| `lib/core/database/database.dart` | New `duplicateRecipe()` DAO |

---

## Open Questions

- Should the duplicate be a silent operation (navigate to edit mode), or show
  a confirmation dialog first? Recommendation: silent — the user is
  immediately taken to edit mode where they can rename and modify.
- "Duplicate" vs "Copy": use `Icons.copy` and tooltip "Duplicate recipe".
