# Discovery Report — bioloop issues

Generated from codebase exploration (AGENTS.md + source analysis) on 2026-05-14.

---

## Issue 1 — Serving/portion math broken for per-100g API foods

### Root cause

When OpenFoodFacts returns no per-serving nutriment data, `FoodResult.fromJson()` falls back to the **per-100g branch**: it sets `servingQuantity = 100`, `servingUnit = 'g'`, and `caloriesPerServing` / `proteinPerServing` / etc. to the per-100g values. The food's `caloriesPerServing = 350` means "350 kcal per 100g".

When the user taps this search result, `_selectFood()` runs:
```dart
_servings = food.servingQuantity;  // → 100
_unit = food.servingUnit;          // → 'g'
```

The form then displays macros computed as `caloriesPerServing * _servings` = **350 × 100 = 35,000 kcal** (100× too high). The `ServingSizePicker` shows "100" as the default quantity.

If the user corrects the Qty field from 100 to 1 (intending "1 serving = 100g"), the preview shows 350 kcal — numerically correct for 100g — but the stored `servingLabel` becomes `"1 g"` instead of `"100 g"`, and the `servings` column stores 1 instead of 100.

### The fix formula

Every macro calculation in the app uses:
```dart
food.caloriesPerServing * quantity   // wrong for servingQuantity != 1
```

It should be:
```dart
food.caloriesPerServing * (quantity / food.servingQuantity)
```

This is **backward-compatible**: for foods with `servingQuantity = 1` (most manually entered or properly parsed foods), the result is identical.

### All locations with the bug

| File | Line(s) | Context |
|------|---------|---------|
| `lib/features/logging/log_food_screen.dart` | 59, 78–93, 221–234, 388–409 | `_selectFood()` init, `_onSaveAsTemplate()`, `_save()`, live macro preview |
| `lib/features/logging/widgets/meal_templates.dart` | 250–258 | `saveCurrentFoodsAsTemplate()` — stores already-wrong macros |
| `lib/features/recipes/recipe_form_screen.dart` | 282–291 | Live total macro calculation in recipe form |
| `lib/core/database/database.dart` | 329–366 | `computeRecipeMacros()` — persisted macro totals |
| `lib/features/recipes/widgets/recipe_ingredient_row.dart` | 20 | Per-row display: `caloriesPerServing * quantity` |

### Bonus: `_selectFood()` default should be 1, not `servingQuantity`

The initial quantity should be `1` (meaning "1 serving"), not `food.servingQuantity` (which for per-100g foods is 100, making no sense as a default serving count). The serving quantity metadata is used for the **denominator** in the fix formula, not as a default multiplier.

---

## Issue 2 — Recipe add ingredient should include recently logged foods

### Finding: already works

`RecipeFormScreen._addIngredient()` (recipe_form_screen.dart:70–79) calls `showSearch<FoodSearchItem?>` with `FoodSearchDelegate`, the **same delegate** used by the log screen. `FoodSearchDelegate._buildContent()` unconditionally renders `_RecentFoodsSection` when `query.isEmpty` (food_search_delegate.dart:49–51). Tapping a recent food calls `close(context, item)`, returning the `FoodSearchItem` to the caller, which then shows `_QuantityDialog`.

**No fix needed** — the feature already exists in both the log screen and recipe ingredient flows.

### If user reports it doesn't work in practice
Possible causes to debug:
1. No foods have been logged yet (empty `food_entries` table) → `recentFoodsProvider` returns empty list → section is `SizedBox.shrink` (line 95)
2. Only recipe-based food entries exist (no `foodId` FK set) → `getRecentFoods()` skips entries with `foodId IS NULL` (database.dart:187)

---

## Issue 3 — Recipe ingredient quantity bug (same root cause as #1)

### Root cause

`_QuantityDialog` (recipe_form_screen.dart:416–468) labels the field `"Quantity in ${widget.unit}"` which for per-100g foods shows `"Quantity in g"`. The user enters, say, `100` (meaning 100g).

Stored as `ingredient.quantity = 100`. Subsequent macro totals use:
```dart
food.caloriesPerServing * ingredient.quantity  // 350 × 100 = 35,000 kcal
```

This should be:
```dart
food.caloriesPerServing * (ingredient.quantity / food.servingQuantity)
```

### Affected files for recipe macros

| File | Line(s) | What's wrong |
|------|---------|--------------|
| `lib/features/recipes/recipe_form_screen.dart` | 104, 282–291 | `quantity` used raw; live totals raw |
| `lib/core/database/database.dart` | 329–366 | `computeRecipeMacros()` uses raw `qty` |
| `lib/features/recipes/widgets/recipe_ingredient_row.dart` | 20 | Display uses `caloriesPerServing * quantity` |

### Quantity semantics

`ingredient.quantity` should continue to store the raw user-entered value (e.g., 100 for 100g). The macro *formula* changes to divide by `servingQuantity`, so the meaning of the stored data doesn't change.

---

## Issue 4 & 5 — Dashboard not refreshing after protein/fat update

### Root cause: missing `ref.invalidate()`

`GoalsScreen._save()` (goals_screen.dart:234–295) writes `db.upsertGoals()` but does **not** call `ref.invalidate()` on any provider afterward.

Every other data-modifying screen in the app does:
- Log food → `ref.invalidate(todaysFoodProvider)`
- Log recipe → `ref.invalidate(todaysFoodProvider)`
- Bodyweight → `ref.invalidate(bodyweightProvider)`
- Settings reset → `ref.read(resetTriggerProvider.notifier).state++`
- Onboarding complete → `ref.invalidate(userGoalsProvider)`, etc.

### The cascade if fixed

```
GoalsScreen._save() → ref.invalidate(userGoalsProvider)
    ↓
userGoalsProvider re-fetches from DB
    ↓
macroTargetsProvider: ref.watch(goalsProvider).getGoals() reads fresh goals
macroTargetsProvider recomputes with new proteinGPerLb / fatCaloriePct
    ↓
DashboardScreen: ref.watch(macroTargetsProvider) gets new values → rebuilds
```

### Fix location

`goals_screen.dart` line 269, after `db.upsertGoals()` succeeds:
```dart
ref.invalidate(userGoalsProvider);
```

### Why `userGoalsProvider` and not `resetTriggerProvider`

`userGoalsProvider` is a `FutureProvider` that watches `resetTriggerProvider`, but calling `ref.invalidate()` on it directly is sufficient to trigger re-fetch. Using `resetTriggerProvider` would unnecessarily re-fetch every provider that watches it (bodyweight, maintenance, etc.). Targeted invalidation is lighter.

---

## Issue 6 — Meal templates drawer shows empty state

### Possible causes (debugging needed)

`MealTemplatesSheet` (meal_templates.dart:47–196) uses a plain `FutureBuilder` calling `db.getAllTemplates()`. The empty state renders when `snapshot.data` is null or an empty list.

The "bugged" behavior could be any of:

1. **Silent error in `_parseTemplateFoods()`** (meal_templates.dart:198–203) — if the JSON in `t.foods` is malformed or uses a schema from before a migration, `TemplateFood.fromJson()` could throw. The `FutureBuilder` would catch the error but not display it (the error handler shows nothing; the empty-state check for `templates.isEmpty` returns true).

2. **Schema migration issue** — v1→v2 migration added columns to `foods` but didn't touch `meal_templates`. If old templates exist with a different JSON format, they'd fail to parse.

3. **Always-empty** — user reports it simply says "no templates yet" every time, suggesting the future never returns data, or the error case is silent.

### Resolution: Issue 8 says to remove templates entirely

Since meal templates are being removed, deep debugging of this bug is **not needed**. The entire feature will be deleted.

---

## Issue 7 — Recent foods should be clickable for re-logging

### Finding: already works

`FoodSearchDelegate._buildContent()` (food_search_delegate.dart:46–71) renders `_RecentFoodsSection` when `query.isEmpty`. Each recent food is a `ListTile` with:
```dart
onTap: () => onSelectItem(item.food)  // line 120
```

This calls `close(context, item)` on the `SearchDelegate`, which returns the `FoodSearchItem` to the caller of `showSearch()`. Both callers handle it identically:
- Log screen (`_onSearch`): receives result → calls `_selectFood(result)`
- Recipe form (`_addIngredient`): receives result → calls `showDialog(_QuantityDialog)` → adds ingredient

**No fix needed** for this specific request — the feature exists. If it doesn't work in practice, the issue may be that no foods have been logged yet (empty recent foods) or a different area of the UX.

---

## Issue 8 — Remove meal templates entirely

### Scope of removal

#### Files to delete
| File | Reason |
|------|--------|
| `lib/features/logging/widgets/meal_templates.dart` | Entire feature (266 lines) |
| `lib/core/database/tables/meal_templates.dart` | Table definition (8 lines) |
| `test/features/logging/meal_templates_test.dart` | Tests for removed feature (350 lines) |

#### Files to edit

**`lib/core/database/database.dart`:**
- Remove `insertTemplate`, `getAllTemplates`, `getTemplate`, `updateTemplate`, `deleteTemplate` methods (lines ~241–265)
- Remove `mealTemplates` from `resetAll()` transaction (line 374)
- Remove `import` of meal_templates table (line 10 area)

**`lib/core/database/database.g.dart`** (generated drift code):
- Regenerate after removing the table definition: `dart run build_runner build`

**`lib/features/logging/log_food_screen.dart`:**
- Remove `import 'widgets/meal_templates.dart'` (line 14)
- Remove `_onSaveAsTemplate()` method (lines 76–100)
- Remove `_openTemplates()` method (lines 102–149)
- Remove bookmark button (lines 305–311, key: `save_as_template_button`)
- Remove "Templates" button (lines 341–348, key: `templates_button`)

**`test/features/settings/settings_test.dart`:**
- Remove `meal_templates` from `countTable()` switch (lines 74–75)
- Remove template seed data (lines 43–47)
- Remove template assertion in reset tests (lines 94, 104, 213)

**`test/database_test.dart`:**
- Remove `meal_templates: insert and read back` test (lines 124–138)

**`AGENTS.md`:**
- Remove "Meal templates" bullet from Key conventions (line 50 area)
- Remove templates line in architecture overview (line 95)

---

---

## Issue 9 — Manual food form requires users to compute calories

### Root cause

`ManualFoodForm` (`manual_food_form.dart:247–260`) requires the user to enter four independent macro fields: calories, protein, carbs, and fat. Calories are stored as a separate column (`caloriesPerServing`) and are **never derived** from the other macros anywhere in the codebase.

The user must manually compute `protein×4 + carbs×4 + fat×9` and type the result. If they adjust any macro, they must redo the math. This is friction for a routine operation.

### Fix: auto-compute with override

Add `onChanged` listeners to protein, carbs, and fat that auto-fill the calories field when all three have valid values. Track manual edits via `_caloriesManuallyEdited` flag to respect user overrides (many food labels don't match 4-4-9 exactly).

### Location

| File | Change |
|------|--------|
| `lib/features/logging/widgets/manual_food_form.dart` | Add `_caloriesManuallyEdited` flag, `onChanged` listeners, `_autoComputeCalories()` method |

---

## Summary of findings

| Issue | Root cause | Fix needed? | Complexity |
|-------|-----------|-------------|------------|
| **1** — serving math | Formula ignores `servingQuantity` denominator | Yes — normalize all `perServing × qty` to `perServing × (qty / servingQuantity)` | Medium (4 files, 9+ sites) |
| **2** — recipe recent foods | Already works | No | None |
| **3** — recipe qty bug | Same as #1, in recipe code paths | Yes — covered by same fix as #1 | Same as #1 |
| **4** — protein not refreshing | Missing `ref.invalidate(userGoalsProvider)` | Yes — 1 line addition | Trivial |
| **5** — fat not refreshing | Same as #4 | Yes — same 1 line addition | Trivial |
| **6** — templates drawer bug | Unknown (feature being removed) | No — covered by #8 removal | None |
| **7** — recent foods clickable | Already works | No | None |
| **8** — remove templates | Feature removal | Yes — full deletion | Medium (6+ files, careful deletion) |
| **9** — auto-compute calories in manual form | Form requires manual 4-4-9 computation | Yes — auto-fill with override | Small (1 file, ~15 lines) |

### Blocks/dependencies

- Fix **#1** and **#3** must be done together (same root cause, overlapping files).
- Fix **#4/#5** are independent and trivial.
- Removing **#8** (templates) should be done **after #1/#3** to avoid merge conflicts on `log_food_screen.dart`.
- Fixing **#6** is unnecessary given #8.
- Issues **#2** and **#7** require no code changes.
- Issue **#9** is independent and touches only `manual_food_form.dart`.
