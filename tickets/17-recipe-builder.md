# T17 — Recipe builder

Create, edit, browse, and log custom recipes. A recipe is a named composite dish with ingredient-level quantities and a total serving size. When logged, it produces a single aggregated `food_entry` with summed macros and a `recipe_id` FK for traceability.

## Tables

New tables `recipes` and `recipe_ingredients` are created in T1 (see PLAN.md §1 for DDL). This ticket defines DAO methods, provider, and UI.

## Files to modify

- `lib/core/database/tables/recipes.dart` — add recipe CRUD (table definition already created in T1)
- `lib/core/database/tables/recipe_ingredients.dart` — add ingredient CRUD + macro computation (table definition already created in T1)

## Files to create

- `lib/providers/recipe_provider.dart` — Riverpod provider
- `lib/features/recipes/recipe_list_screen.dart` — browse/create/edit recipes
- `lib/features/recipes/recipe_form_screen.dart` — add/remove ingredients, set name and yield
- `lib/features/recipes/widgets/recipe_ingredient_row.dart` — ingredient list item in form
- `lib/features/recipes/widgets/log_recipe_sheet.dart` — portion input → save as food_entry

## DAO methods: `recipes.dart`

Add to `lib/core/database/tables/recipes.dart`:

- `Future<int> insertRecipe(Recipe recipe)` — returns new recipe ID
- `Future<Recipe?> getRecipe(int id)` — fetch recipe by ID
- `Future<List<Recipe>> getAllRecipes()` — all recipes, ordered by name
- `Future<void> updateRecipe(Recipe recipe)` — update name, serving_size, serving_label
- `Future<void> deleteRecipe(int id)` — deletes recipe and cascades to ingredients

## DAO methods: `recipe_ingredients.dart`

Add to `lib/core/database/tables/recipe_ingredients.dart`:

- `Future<void> insertIngredient(RecipeIngredient ingredient)` — add ingredient to recipe
- `Future<List<RecipeIngredient>> getIngredients(int recipeId)` — all ingredients for a recipe, joined with `foods` for macro data
- `Future<void> updateIngredient(RecipeIngredient ingredient)` — change quantity or food
- `Future<void> deleteIngredient(int id)` — remove ingredient from recipe
- `Future<void> deleteIngredientsForRecipe(int recipeId)` — bulk remove (used before re-inserting all ingredients on edit)

### Macro computation

Define alongside ingredients DAO in `recipe_ingredients.dart`:

- `Future<RecipeMacros> computeRecipeMacros(int recipeId)` — for each ingredient: `food.macro_per_serving × ingredient.quantity`, sum all ingredients, return total calories/protein/carbs/fat + per-serving macros (total / recipe.serving_size)
- Returns a `RecipeMacros` data class: `(calories, protein_grams, carbs_grams, fat_grams, perUnitCalories, perUnitProtein, perUnitCarbs, perUnitFat)`

## Provider: `recipeProvider`

`lib/providers/recipe_provider.dart`

- `recipeListProvider` — `FutureProvider<List<Recipe>>` — all recipes
- `recipeDetailProvider(int id)` — `FutureProvider` — recipe + ingredients + computed macros
- `allRecipesProvider` — `StreamProvider` — auto-refresh via `databaseProvider` watch (invalidates on recipe insert/update/delete)
- Entry point on log screen: "Recipes" button → opens `RecipeListScreen`
- When logging a recipe, the provider computes scaled macros and inserts one `food_entry` with:
  - `food_id = null`
  - `recipe_id = recipe.id`
  - `name = recipe.name`
  - `servings = portion / recipe.serving_size` (e.g. 200g / 600g = 0.333)
  - `serving_label = recipe.serving_label`
  - `calories`, `protein_grams`, `carbs_grams`, `fat_grams` = `total_macros × (portion / serving_size)`

## UI

### Recipe list screen (`recipe_list_screen.dart`)

- AppBar with title "Recipes" and "+" button to create new recipe
- List of recipe cards: name, total macros, serving size (e.g. "600g"), macros per serving (e.g. "350 kcal / 100g")
- Tap a recipe → `recipe_form_screen.dart` in view mode, with "Log" button
- Long-press → confirmation dialog → delete
- Empty state: "No recipes yet. Tap + to create one."

### Recipe form screen (`recipe_form_screen.dart`)

Used for both create and edit (distinguished by whether a recipe ID is passed):

- **Name field**: text input, required
- **Serving size section**:
  - Amount: number input (e.g. 600)
  - Label: text input (e.g. "g", "cups", "slices")
  - Displayed total macros computed live from ingredient list
  - Displayed per-unit macros computed live (total / serving_size)
- **Ingredients list**: scrollable list of `RecipeIngredientRow` widgets
  - Each row shows: food name, quantity, unit label, macros contributed
  - Swipe to delete with confirmation
  - Tap to edit quantity
  - Reorderable (drag handle)
- **Add ingredient**: button at bottom of list → opens `food_search_delegate` (T4) → select food → enter quantity → confirms → added to list
- **Save**: button enabled when name is non-empty and at least one ingredient exists
- **View mode**: same layout but fields read-only; "Log" FAB replaces Save

### Recipe ingredient row (`recipe_ingredient_row.dart`)

- Displays: food name, quantity × serving_label, macro summary (e.g. "245 kcal")
- Options: edit quantity (inline tap), delete (swipe or icon)

### Log recipe sheet (`log_recipe_sheet.dart`)

Bottom sheet opened from recipe detail view (or from log screen recipe picker):

- Recipe name as title
- Computed total macros display
- Portion input: number field with unit label (e.g. "200 g")
- Scale preview: "0.33× recipe — 485 kcal"
- Meal type selector (reuse `meal_type_selector.dart` from T6)
- "Log to today" button → saves aggregated `food_entry` with:
  - `food_id = null`, `recipe_id = recipe.id`
  - `name = recipe.name`
  - Macros scaled by `portion / serving_size`
  - `serving_label = recipe.serving_label`
  - `servings = portion / recipe.serving_size` (e.g. 200g / 600g = 0.333)

### Integration with log food screen (T6)

- "Recipes" button in log screen (alongside search bar and manual entry)
- Tapping it opens `RecipeListScreen` in picker mode (tapping a recipe directly opens `log_recipe_sheet` without going to detail view)
- Selected recipe portion → back to log screen with entry pre-filled in today's log

## Acceptance criteria

- Can create a recipe with name, serving size, and 2+ ingredients from food search
- Live macro totals update as ingredients are added/removed
- Can edit recipe name, serving size, and ingredients
- Can delete a recipe
- Can log a recipe with a custom portion → single aggregated entry in today's food log
- Logged entry has correct scaled macros, `recipe_id` FK, and recipe name
- Logged entry appears in history screen (T8) alongside other entries
- Recipes list survives app restart (persisted in DB)
- `food_entries` with `recipe_id` can be traced back to original recipe

## Testing

### DAO

- **Unit — insert and read recipe**: insert recipe, read back, verify all fields including serving_size, serving_label
- **Unit — insert ingredients**: add 2 ingredients to recipe, fetch ingredients list, verify count and food_id
- **Unit — delete recipe cascades**: delete recipe, verify ingredients deleted (FK cascade)
- **Unit — compute macros single ingredient**: recipe with 1 ingredient (200 kcal/serving, 2 servings) → total = 400 kcal; serving_size = 400g → per_unit = 1 kcal/g
- **Unit — compute macros multiple ingredients**: recipe with 3 ingredients, verify sum of individual macros = total
- **Unit — compute macros empty recipe**: no ingredients → total macros = 0
- **Unit — update ingredient**: change quantity, recompute, verify new total

### Provider

- **Unit — recipe list provider**: insert 3 recipes, verify list contains all 3
- **Unit — log recipe creates food_entry**: call `logRecipe(recipeId, portion, mealType)`, verify food_entry inserted with correct recipe_id, scaled macros, and meal_type

### Widget

- **Widget — create recipe**: fill name + serving size + add 2 ingredients → save → recipe appears in list
- **Widget — edit recipe**: tap existing recipe → change ingredient quantity → save → verify updated in DB
- **Widget — delete recipe**: long-press → confirm → recipe removed from list
- **Widget — log recipe**: select recipe → enter portion → select meal type → confirm → verify food_entry in today's log
- **Widget — live macro preview**: add/remove ingredients; verify total macro display updates
- **Widget — empty state**: no recipes → "No recipes yet" message displayed
- **Widget — validation**: try to save with empty name → save button disabled; try to save with no ingredients → save button disabled

## Human verification

- [ ] `flutter analyze` passes with zero errors
- [ ] `flutter test` passes all DAO, provider, and widget tests
- [ ] Tap "Recipes" on log screen → empty state shown
- [ ] Tap + → create recipe "Chicken Salad" with serving size 400g
- [ ] Add 2 ingredients (200g chicken breast, 100g mayo) from food search — live totals update
- [ ] Save → recipe appears in list with computed macros
- [ ] Tap recipe → detail shows name, serving size, per-unit macros, ingredient list
- [ ] Tap "Log" → enter portion 150g → select meal type → confirm
- [ ] Check today's log — "Chicken Salad — 150 g" entry appears with correct scaled macros
- [ ] Check food_entries table — entry has `recipe_id` pointing to the recipe
- [ ] Edit recipe → change serving size to 500g → save → per-unit macros recalculated
- [ ] Long-press recipe → delete with confirmation → removed from list
- [ ] Logged entry with `recipe_id` appears in history screen (T8)
- [ ] Logged entry can be deleted from history (swipe-to-delete) — recipe is NOT deleted (independent lifecycle)
- [ ] App restart — all recipes preserved

## Dependencies

T1 (recipe + recipe_ingredients tables exist), T4 (food search for ingredient selection), T5 (manual food form to create ingredients on the fly), T6 (log screen integration point, food_entries write), T8 (history screen shows recipe-sourced entries)

## Agent instructions (app state tracking)

After completing the work in this ticket, append a row to the `## App State` table in `AGENTS.md`:

| T17 — Recipe builder | ✅ Complete | YYYY-MM-DD | AI |

See `AGENTS.md` for the current state table.
