# Discovery Report — issues.txt

**Date:** 2026-05-16  
**Author:** opencode

---

## Issue 1 & 2: Recipe Management from "Log Recipe" View

### Current Implementation

**File:** `lib/features/recipes/recipe_list_screen.dart`

The `RecipeListScreen` uses a `pickerMode` parameter to distinguish between two modes:

| Mode | Location | Tap | Long-Press | Trailing Actions |
|------|----------|-----|------------|------------------|
| `pickerMode: true` | Log screen (via `CombinedLogScreen`) | Opens `LogRecipeSheet` | No-op | Chevron right only |
| `pickerMode: false` | Recipes tab | Opens `RecipeFormScreen` (edit) | Delete with haptic | Edit, Duplicate, Delete buttons |

**Key code sections:**
- Line 12-16: `pickerMode` parameter declaration
- Line 101-127: `_openRecipe()` method with mode-based branching
- Line 172-249: `_RecipeCard` widget with mode-specific UI
- Line 128-149: `_deleteRecipe()` method (exists but only accessible in management mode)

**Current flow from Log screen:**
```
CombinedLogScreen._onLogRecipe() (line 87-92)
  → RecipeListScreen(pickerMode: true, loggedAt: _currentDate)
    → _RecipeCard.onTap → _openRecipe()
      → if pickerMode: showModalBottomSheet(LogRecipeSheet)
```

### Proposed Changes

Remove `pickerMode` entirely. Unified interaction model:

| Action | Behavior |
|--------|----------|
| **Tap** | Open `LogRecipeSheet` (log the recipe) |
| **Long-press** | Delete recipe with confirmation dialog |
| **Edit button** | Open `RecipeFormScreen` to edit recipe |

**UI changes to `_RecipeCard`:**
- Remove chevron icon from trailing
- Add `Icons.edit` button to trailing row (always visible)
- Keep delete button in trailing row
- Optionally remove duplicate button (or keep it)
- Long-press triggers delete with haptic feedback (existing pattern)

**Files to modify:**
1. `lib/features/recipes/recipe_list_screen.dart`
   - Remove `pickerMode` parameter
   - Simplify `_openRecipe()` to always log
   - Update `_RecipeCard` trailing actions
   - Update tooltip text

2. `lib/features/logging/combined_log_screen.dart` (line 87-92)
   - Change `RecipeListScreen(pickerMode: true, ...)` to `RecipeListScreen(loggedAt: _currentDate)`

**Edge cases to consider:**
- Should delete show confirmation dialog? (Yes, per existing pattern line 128-149)
- Should duplicate button be kept? (User feedback needed)
- Should edit button open form in "edit mode" or "duplicate mode"? (Edit mode, per issue description)

---

## Issue 3: Accent Color Customization

### Current Implementation

**File:** `lib/theme/theme.dart`

```dart
class AppTheme {
  static ThemeData get light => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.deepPurple,  // Hardcoded
    ),
  );
  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.deepPurple,  // Hardcoded
      brightness: Brightness.dark,
    ),
  );
}
```

**Settings screen:** `lib/features/settings/settings_screen.dart`
- Only contains "Reset All Data" option
- No theme customization

**Database:** `lib/core/database/tables/user_goals.dart`
- 13 columns, no color preference field
- Schema version 1, no migration strategy

### Proposed Implementation

**1. Database schema change**

Add to `user_goals` table:
```dart
IntColumn get accentColorSeed => integer().nullable()();
```

- Store color as ARGB int value
- `null` = use default (deepPurple)
- No migration needed (app not published, schema v1)

**2. Settings UI**

Add to `lib/features/settings/settings_screen.dart`:
- New ListTile "Accent Color"
- Opens color picker dialog (bottom sheet or `AlertDialog`)
- Predefined palette of 6-8 colors (Material primary colors)
- Save selected color to `user_goals` table via `goalsProvider`

**3. Theme system update**

Modify `lib/theme/theme.dart`:
```dart
class AppTheme {
  static ThemeData light([Color? seedColor]) => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: seedColor ?? Colors.deepPurple,
    ),
  );
  static ThemeData dark([Color? seedColor]) => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: seedColor ?? Colors.deepPurple,
      brightness: Brightness.dark,
    ),
  );
}
```

**4. App wire-up**

Modify `lib/app.dart`:
- Watch `userGoalsProvider` for `accentColorSeed` value
- Convert int to `Color` object
- Pass to `AppTheme.light()` / `AppTheme.dark()`

**Files to modify:**
1. `lib/core/database/tables/user_goals.dart` - add column
2. `lib/features/settings/settings_screen.dart` - add color picker UI
3. `lib/theme/theme.dart` - accept optional seedColor parameter
4. `lib/app.dart` - read color from DB and apply to theme

**Design decisions:**
- Predefined palette vs. full color picker? → **Predefined palette** (simpler, more cohesive)
- Should light/dark themes share the same seed? → **Yes** (Material 3 handles brightness)
- Where to show current color preview? → Show selected color swatch in settings tile

---

## Issue 4: Maintenance Progress Bar Shows "1/14 Days"

### Current Implementation

**File:** `lib/features/dashboard/widgets/maintenance_card.dart`

`_countDataDaysProvider` (lines 12-34):
```dart
final _countDataDaysProvider = FutureProvider<int>((ref) async {
  ref.watch(dataTriggerProvider);
  final db = ref.watch(databaseProvider);
  final now = DateTime.now();
  final cutoff = now.subtract(const Duration(days: 30));
  final cutoffStr = /* date string */;

  final foods = await db.getEntriesPaginated(limit: 365);
  final weights = await db.getWeights();

  final foodDates = foods
      .map((e) => e.loggedAt.substring(0, 10))
      .where((d) => d.compareTo(cutoffStr) >= 0)
      .toSet();

  final weightDates = weights
      .map((e) => e.loggedAt.substring(0, 10))
      .where((d) => d.compareTo(cutoffStr) >= 0)
      .toSet();

  return foodDates.intersection(weightDates).length;  // ← BUG HERE
});
```

**Display logic** (lines 88-129):
- Shows progress bar: `$count/14`
- Only counts days with **both** food AND weight entries

### Root Cause

The `_countDataDaysProvider` uses set intersection, counting only days where the user logged **both** food and weight. However:

1. The maintenance algorithm (`lib/core/algorithms/maintenance_calculator.dart`) uses **forward-fill** for weights (lines 57-78)
2. From AGENTS.md:
   > "Dates before first weight entry use the oldest weight (assumes no change prior to onboarding)"
   > "This ensures new users with sparse early data can still get maintenance estimates"

3. The algorithm can calculate maintenance with:
   - Any day that has food logged
   - Weight is assumed via forward-fill from nearest logged weight

**Example scenario:**
- User logs food for 10 different days
- User logs weight only on day 1
- Current progress bar: `1/14` (only day 1 has both)
- Algorithm can actually use: `10` days (food on all 10, weight forward-filled)

### Fix

Change `_countDataDaysProvider` to count **food entry dates only**:

```dart
final _countDataDaysProvider = FutureProvider<int>((ref) async {
  ref.watch(dataTriggerProvider);
  final db = ref.watch(databaseProvider);
  final now = DateTime.now();
  final cutoff = now.subtract(const Duration(days: 30));
  final cutoffStr = /* date string */;

  final foods = await db.getEntriesPaginated(limit: 365);

  final foodDates = foods
      .map((e) => e.loggedAt.substring(0, 10))
      .where((d) => d.compareTo(cutoffStr) >= 0)
      .toSet();

  return foodDates.length;  // Count food days only
});
```

**Rationale:**
- Weight forward-fill means any day with food can be used
- Progress bar should reflect usable data points for the algorithm
- User logs food more frequently than weight, so this is more motivating

**File to modify:**
- `lib/features/dashboard/widgets/maintenance_card.dart` (lines 12-34)

**Testing consideration:**
- Verify behavior when user has logged food but no weight yet
- Should show food count, not 0

---

## Summary

| Issue | Files | Estimated LOC | Complexity |
|-------|-------|---------------|------------|
| 1 & 2: Recipe management | `recipe_list_screen.dart`, `combined_log_screen.dart` | ~40 | Low |
| 3: Accent color | `user_goals.dart`, `settings_screen.dart`, `theme.dart`, `app.dart` | ~80 | Medium |
| 4: Maintenance progress | `maintenance_card.dart` | ~5 | Low |

**Total:** ~125 lines across 6 files

---

## Recommendations

1. **Issue 4 first** - Smallest change, immediate user benefit, no UI risk
2. **Issues 1 & 2 second** - Core functionality improvement, well-defined scope
3. **Issue 3 last** - Requires most files changed, involves design decisions (color palette)

---

## Issue 5: Edit/Delete Saved Foods from "My Foods" View

### Current Implementation

**Files:** `lib/features/logging/widgets/food_search_delegate.dart`, `lib/features/logging/widgets/manual_food_form.dart`

The "My Foods" tab in `FoodSearchDelegate` displays a list of local foods from `searchLocalByRecency()`. Current interaction:
- Tap → Opens `QuickFoodLogSheet` to log the food
- "Create custom food" ListTile → Opens `ManualFoodForm` to create new food
- No edit or delete functionality

**Key code sections:**
- Line 182-243: `_LocalSearchContent` widget builds the list
- Line 224-239: ListTile for each food item (tap only, no trailing actions)
- Line 210-217: "Create custom food" ListTile at top of list

**Current flow:**
```
FoodSearchDelegate (search mode: "local")
  → _LocalSearchContent
    → ListView
      → "Create custom food" ListTile
      → Food items (ListTile with onTap → onQuickLog or onSelectItem)
```

**ManualFoodForm capabilities** (creation only):
- Name (required)
- Quantity + Unit (dropdown with 11 common units + custom option)
- Calories per serving (required)
- Protein/Carbs/Fat per serving in grams (required, auto-computes calories via 4-4-9 rule)
- Saves to `foods` table via `db.insertFood()`

### Proposed Changes

**Unified interaction model for "My Foods" tab:**

| Action | Behavior |
|--------|----------|
| **Tap** | Open `QuickFoodLogSheet` to log the food (unchanged) |
| **Long-press** | Delete food with confirmation dialog |
| **Edit button** | Open `ManualFoodForm` in edit mode (pre-filled with existing data) |

**UI changes to food list items:**
- Add `Icons.edit` button to trailing of each ListTile
- Add `Icons.delete_outline` button to trailing (or keep delete on long-press only)
- Long-press triggers delete confirmation with haptic feedback (similar to recipe pattern)

**Files to modify:**
1. `lib/features/logging/widgets/food_search_delegate.dart`
   - Update `_LocalSearchContent` to accept `onEditFood` and `onDeleteFood` callbacks
   - Modify ListTile to include trailing edit/delete buttons
   - Add long-press gesture detector for delete
   - Pass callbacks from `FoodSearchDelegate`

2. `lib/features/logging/widgets/manual_food_form.dart`
   - Add optional `Food? existingFood` parameter
   - Pre-fill all form fields when editing
   - Change save logic to `db.upsertFood()` or `db.updateFood()` when editing
   - Update app bar title ("Edit Food" vs "Custom Food")

3. `lib/core/database/database.dart` (may need update)
   - Add `updateFood()` method OR use existing `upsertFood()` (already exists, line 118-128)
   - `upsertFood()` updates by barcode if present, otherwise inserts — may need modification for manual foods

**Edge cases to consider:**
- **Food entries reference deleted foods**: When deleting a food, what happens to existing `food_entries` that reference it?
  - Option A: Prevent deletion if food has entries (show error dialog)
  - Option B: Cascade delete (delete all entries referencing this food)
  - Option C: Soft delete (mark food as deleted but keep in DB)
  - **Recommendation:** Option A — show dialog "This food is used in X log entries. Delete anyway?" with cancel/confirm. If confirmed, cascade delete.

- **Editing foods that are already logged**: Should changes propagate to past entries?
  - **No** — past entries are snapshots at time of logging. Only affect future logs.

- **API-imported foods**: Should users be able to edit foods from OpenFoodFacts?
  - Per issue: only "My Foods" tab, which includes all local foods
  - Foods with `source == 'open_food_facts'` can be edited (user may want to fix serving size, etc.)

### Implementation Details

**Edit form flow:**
```
Tap edit button on food item
  → Open ManualFoodForm(existingFood: food)
    → Form pre-filled with food's data
    → User edits fields
    → Tap Save
      → db.upsertFood() with food.id
      → Pop from navigator
      → Food list refreshes (via callback or provider invalidation)
```

**Delete flow:**
```
Long-press or tap delete button
  → Show confirmation dialog
    → "Delete [food name]? This will also delete X log entries."
    → Cancel / Delete buttons
  → If confirmed:
    → Delete food_entries referencing this food (FK-safe order)
    → Delete food from foods table
    → Show success snackbar or just close
```

**Database operations:**

For editing:
```dart
await db.upsertFood(FoodsCompanion(
  id: Value(existingFood.id),  // Include ID for update
  name: Value(newName),
  servingLabel: Value(newLabel),
  servingQuantity: Value(newQty),
  servingUnit: Value(newUnit),
  caloriesPerServing: Value(newCals),
  proteinPerServing: Value(newProtein),
  carbsPerServing: Value(newCarbs),
  fatPerServing: Value(newFat),
  // barcode, brand, source, createdAt unchanged or Value.null
));
```

For deletion (FK-safe order):
```dart
await transaction(() async {
  // First delete entries that reference this food
  await (delete(foodEntries)..where((e) => e.foodId.equals(foodId))).go();
  // Then delete the food itself
  await (delete(foods)..where((f) => f.id.equals(foodId))).go();
});
```

### Complexity Assessment

| Aspect | Complexity | Notes |
|--------|-----------|-------|
| Edit form | Medium | Reuse `ManualFoodForm`, add pre-fill logic |
| Delete UI | Low | Add buttons + long-press, similar to recipes |
| Database update | Low | `upsertFood()` exists, may need minor tweak |
| Delete with FK handling | Medium | Need to count/delete referencing entries first |
| Provider invalidation | Low | May need new trigger or refresh mechanism |

**Estimated effort:**
- Ticket 6 (UI changes): 45 minutes
- Ticket 7 (Edit form + DB): 40 minutes

---

## Summary Table

| Issue | Files | Estimated LOC | Complexity | Priority |
|-------|-------|---------------|------------|----------|
| 1 & 2: Recipe management | `recipe_list_screen.dart`, `combined_log_screen.dart` | ~40 | Low | High |
| 3: Accent color | `user_goals.dart`, `settings_screen.dart`, `theme.dart`, `app.dart` | ~80 | Medium | Medium |
| 4: Maintenance progress | `maintenance_card.dart` | ~5 | Low | High |
| 5: Food edit/delete | `food_search_delegate.dart`, `manual_food_form.dart`, `database.dart` | ~90 | Medium | Medium |

**Total:** ~215 lines across 9 files
