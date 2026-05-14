# Discovery Findings

## Issue 1: Recent foods stale after logging

### Root cause
`recentFoodsProvider` (`lib/providers/recent_foods_provider.dart:11-20`) is a `FutureProvider` that calls `ref.read(databaseProvider)` — a one-shot read, not a watch. Since `databaseProvider` is overridden once in `main.dart` and never changes, `recentFoodsProvider` **never invalidates** after initial creation.

Meanwhile, every food-logging path already increments `dataTriggerProvider`:
- `log_food_screen.dart:194` — `_save()` after normal log
- `log_food_screen.dart:291` — after logging a recipe
- `log_food_screen.dart:401` — after delete from today's entries
- `quick_food_log_sheet.dart:95` — after quick-log
- `log_recipe_sheet.dart` — after recipe log (need to verify)

But `recentFoodsProvider` never watches this trigger.

### Fix
Add `ref.watch(dataTriggerProvider)` to `recentFoodsProvider`. This makes it reactive to any food mutation. Since `dataTriggerProvider` is a `StateProvider<int>` incremented everywhere food entries are created/deleted, watching it will invalidate `recentFoodsProvider` on every mutation.

Note: `dataTriggerProvider` should not be confused with `resetTriggerProvider` (used for full data reset). `dataTriggerProvider` is the right one here — it fires on every individual log/delete, not just resets.

### Files to modify
- `lib/providers/recent_foods_provider.dart` — add `ref.watch(dataTriggerProvider)`

---

## Issue 2: Recipe ingredient display format

### Root cause
`recipe_ingredient_row.dart:27` renders:
```dart
'${ingredient.quantity.toStringAsFixed(1)} × ${food.servingLabel} — ${cals.toStringAsFixed(0)} kcal'
```

For per-100g foods, `food.servingLabel` is often just `"g"`. The result: `100.0 × g — 370 kcal`. The `.0` decimal and the raw `×` with the bare label look awkward.

### Existing serving-label formatting
Three identical copies of `_buildLabel()` exist across the codebase:
- `log_food_screen.dart:143` — `_buildLabel(double qty, String unit)`
- `quick_food_log_sheet.dart:44` — `_buildLabel(double qty, String unit)`
- `manual_food_form.dart:49` — `_buildLabel()` (reads from controllers)

The common pattern:
```dart
String _buildLabel(double qty, String unit) {
  final qtyStr = qty == qty.roundToDouble()
      ? qty.toInt().toString()
      : qty.toStringAsFixed(1);
  return '$qtyStr $unit';
}
```

This rounds whole numbers cleanly (e.g., `"100 g"` not `"100.0 g"`).

### Fix
1. Extract `_buildLabel` into a shared utility, e.g. `lib/core/utils/serving_helpers.dart`
2. Replace all 3 inline copies with the shared function
3. Use the shared function in `recipe_ingredient_row.dart` to format the serving line as `"${formattedQty} ${food.servingUnit}"` instead of `"${rawQty} × ${food.servingLabel}"`
4. This requires `servingUnit` to be passed to the ingredient row — it's already available via `item.food.servingUnit`

### Additional observation: today's entries also lack serving info
`log_food_screen.dart:497-521` (`_TodayEntriesSection`) shows subtitles like:
```
370 cal  •  P20g  C45g  F8g  •  14:30
```

No quantity/unit is shown. This is the same pattern as the history tab (Issue 3). These could be fixed together if desired.

### Files to modify
- `lib/core/utils/serving_helpers.dart` (new file)
- `lib/features/logging/log_food_screen.dart` (replace inline `_buildLabel`)
- `lib/features/logging/widgets/quick_food_log_sheet.dart` (replace inline `_buildLabel`)
- `lib/features/logging/widgets/manual_food_form.dart` (replace inline `_buildLabel`)
- `lib/features/recipes/widgets/recipe_ingredient_row.dart` (use shared helper)

---

## Issue 3: History tab entries missing quantity/unit

### Root cause
`history_screen.dart:298-306` renders each entry's subtitle as:
```dart
subtitle: Text(
  '${entry.calories.toInt()} cal  •  P${entry.proteinGrams.toStringAsFixed(0)}g  C${entry.carbsGrams.toStringAsFixed(0)}g  F${entry.fatGrams.toStringAsFixed(0)}g  •  $timeStr',
),
```

`entry.servings` and `entry.servingLabel` are available on the `FoodEntry` model (both are columns in `food_entries` table) but are not displayed.

### FoodEntry model (relevant fields)
- `servings: double` — the numeric quantity logged
- `servingLabel: String` — already-formatted string like `"100 g"` or `"2 servings"`

Note: `servingLabel` already contains the formatted quantity+unit (set by `_buildLabel()` during logging), so it can be used directly.

### Fix
Add `entry.servingLabel` to the subtitle. Simple approach:
```
'${entry.calories.toInt()} cal  •  ${entry.servingLabel}  •  P${...}g  C${...}g  F${...}g  •  $timeStr'
```

Note: The delete confirmation dialog at line 255 also only shows `entry.name`. Adding serving info there would be nice but is optional.

### Files to modify
- `lib/features/history/history_screen.dart` — add serving info to subtitle (line ~301)

---

## Issue 4: Edit recipe

### Current state
Editing **is already implemented** in `RecipeFormScreen`. When `recipeId` is non-null:
1. `initState()` calls `_loadRecipe()` (line 35-39)
2. Loads full recipe + ingredients via `recipeDetailProvider(recipeId).future`
3. Populates form fields (`_nameController`, `_servingSizeController`, `_servingLabelController`, `_ingredients`)
4. On save: calls `db.updateRecipe()` + `db.deleteIngredientsForRecipe()` + re-inserts all ingredients (line 200-210)

### Access point
In `recipe_list_screen.dart:113-117`, tapping a recipe card pushes `RecipeFormScreen(recipeId: recipe.id)`. This opens the form in edit mode.

### Discoverability problem
The `_RecipeCard` widget only shows:
- Title (recipe name)
- Subtitle (serving size + unit)
- Trailing delete `IconButton` (in non-picker mode)

Tapping the card opens it for editing, but there's no explicit **edit icon**. Users may not know tapping opens the edit form. A pencil/edit icon alongside the delete button would make this obvious.

### Files to modify (if adding explicit edit icon)
- `lib/features/recipes/recipe_list_screen.dart` — add edit `IconButton` to `_RecipeCard` trailing

---

## Issue 5: Duplicate recipe

### Current state
Does not exist. No duplicate/clone functionality anywhere.

### What needs to happen
A "Duplicate" action on `_RecipeCard` that:
1. Loads `recipeDetailProvider(recipe.id)` to get recipe + ingredients
2. Creates a new recipe with `name = "${recipe.name} (Copy)"` (or similar)
3. Re-inserts all ingredients (same food IDs, same quantities)
4. Invalidates `recipeListProvider` to refresh the list
5. Optionally navigates to the newly created recipe's edit form

### Implementation considerations
- The save logic in `RecipeFormScreen._save()` creates a pattern to follow: insert recipe, then loop over ingredients calling `db.insertIngredient()`
- `RecipeService` already has `insertRecipe()` and `insertIngredient()` methods
- `recipeDetailProvider` already returns `List<IngredientWithFood>` with full ingredient data
- The `Recipes` table has `name`, `servingSize`, `servingLabel`, `createdAt`, `updatedAt` — all must be copied (with new timestamps)

### Code flow
```
1. User taps "Duplicate" → confirmation dialog (optional)
2. Load detail = ref.read(recipeDetailProvider(recipe.id))
3. db.insertRecipe() with copied fields + "(Copy)" name suffix
4. For each ingredient: db.insertIngredient() with new recipeId
5. ref.invalidate(recipeListProvider)
```

### Files to modify
- `lib/features/recipes/recipe_list_screen.dart` — add duplicate action (icon or popup menu)
- Consider: extract duplication logic into `RecipeService` for reusability

---

## Issue 6: "Create custom food" before recent foods

### Root cause
In `food_search_delegate.dart:48-78`, `_buildContent()` lays out items in this order:
```dart
children: [
  if (query.isEmpty)
    _RecentFoodsSection(...),       // 1st: recent foods (only when empty query)
  ListTile(                          // 2nd: create custom food
    title: 'Create custom food',
    ...
  ),
  if (query.isNotEmpty) ...[         // 3rd: search results (only when non-empty)
    Divider(),
    _DebouncedSearch(...),
  ],
],
```

The user wants "Create custom food" **first**, then recent foods, then search results.

### Fix
Swap the order — move the "Create custom food" `ListTile` before the `_RecentFoodsSection`.

Note: The "Create custom food" tile is already always-shown (condition is outside the `if (query.isEmpty)` block), so it stays visible even when query is typed and recent foods disappear. This behavior is correct and should be preserved.

### Files to modify
- `lib/features/logging/widgets/food_search_delegate.dart` — reorder items in `_buildContent()`

---

## Issue 7: ManualFoodForm auto-calc doesn't overwrite

### Root cause
`manual_food_form.dart:102`:
```dart
if (_caloriesManuallyEdited) return;
```

When the user edits the calories field directly, `_caloriesManuallyEdited` is set to `true` (line 274). From that point on, `_autoComputeCalories()` bails out immediately and never recalculates — even if the user subsequently changes the macro values.

The only way to re-enable auto-compute is to clear **all three** macro fields to empty/zero (line 96-101), which is undiscoverable.

### Desired behavior
From the issue: "the calculated calories should re-calculate each time one of the macros are edited. the user should still be able to edit the calories directly after the fact, but subsequent changes to the macros should re-calculate the calories and overwrite that."

Translation: **Always** recalculate calories from macros when a macro field changes, regardless of whether the user touched the calories field. The user can still edit calories directly, but the next macro edit will overwrite it.

This is a simpler, more predictable model. The re-entrancy guard (`_settingCalories`, line 32/109/111) already prevents infinite loops — `_autoComputeCalories()` sets `_settingCalories = true` before writing to `_caloriesController`, and the `onChanged` callback (line 274) checks it before setting `_caloriesManuallyEdited`.

### Fix
Remove the `_caloriesManuallyEdited` flag and its guard. Keep:
- The `allZero` reset logic (line 96-101) — this is fine as a "clear all → reset" signal
- The `_settingCalories` re-entrancy guard — this prevents the calories-onChanged from triggering another auto-compute

Simplified `_autoComputeCalories()`:
```dart
void _autoComputeCalories() {
  final p = double.tryParse(_proteinController.text);
  final c = double.tryParse(_carbsController.text);
  final f = double.tryParse(_fatController.text);
  if (p == null || c == null || f == null) return;
  if (p < 0 || c < 0 || f < 0) return;
  final computed = (p * 4) + (c * 4) + (f * 9);
  final text = computed == computed.roundToDouble()
      ? computed.toInt().toString()
      : computed.toStringAsFixed(1);
  _settingCalories = true;
  _caloriesController.text = text;
  _settingCalories = false;
}
```

This removes:
- `_caloriesManuallyEdited` field (line 31)
- The `allZero` block (lines 96-101) — optional, can keep as reset behavior or remove
- The `if (_caloriesManuallyEdited) return;` guard (line 102)
- The `onChanged` calories handler setting `_caloriesManuallyEdited` (line 274)

### Files to modify
- `lib/features/logging/widgets/manual_food_form.dart`

---

## Summary of Files to Modify

| File | Issues |
|------|--------|
| `lib/providers/recent_foods_provider.dart` | #1 |
| `lib/core/utils/serving_helpers.dart` (new) | #2 (shared util extraction) |
| `lib/features/logging/log_food_screen.dart` | #2 (replace inline `_buildLabel`) |
| `lib/features/logging/widgets/quick_food_log_sheet.dart` | #2 (replace inline `_buildLabel`) |
| `lib/features/logging/widgets/manual_food_form.dart` | #2 (replace inline `_buildLabel`), #7 (auto-calc behavior) |
| `lib/features/recipes/widgets/recipe_ingredient_row.dart` | #2 (use shared formatter) |
| `lib/features/history/history_screen.dart` | #3 |
| `lib/features/recipes/recipe_list_screen.dart` | #4 (edit icon), #5 (duplicate) |
| `lib/features/logging/widgets/food_search_delegate.dart` | #6 |

## Dependency Order

```
#6 ──┐                     (independent — swap order)
#7 ──┤                     (independent — simplify auto-calc)
#1 ──┤                     (independent — add watch)
     ├── all independent
#3 ──┤                     (independent — add text to subtitle)
#2 ──┤                     (shared util + update 4 consumers)
#5 ──┤                     (needs understanding of recipe CRUD)
#4 ──┘                     (needs user clarification on scope)
```

Steps #6, #7, #1, #3 have zero dependencies and can be done in any order. Step #2 (shared serving util) should precede fixing recipe_ingredient_row if we choose the extraction approach. Step #5 is the most complex and should be done last.
