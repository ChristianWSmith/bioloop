# Discovery Findings

Results of the codebase exploration to understand the scope and root causes
of each issue in `issues.txt`.

---

## Issue 1 — Recent foods stale in recipe ingredient search

### Root Cause
`recentFoodsProvider` (`lib/providers/recent_foods_provider.dart:11`) uses
`ref.read(databaseProvider)` instead of `ref.watch(resetTriggerProvider)` or
`ref.watch(dataTriggerProvider)`. This means the provider does NOT
auto-refresh when new foods are logged. The stale cached value is displayed
until the app restarts (which re-creates the ProviderContainer).

### Files affected
- `lib/providers/recent_foods_provider.dart` — add `ref.watch(resetTriggerProvider)` to trigger re-fetch
- Possibly `lib/features/recipes/recipe_form_screen.dart` if the `showSearch` needs invalidation

### Test coverage
Test at `test/features/recipes/recipes_test.dart:681-732` seeds data _before_
opening the screen, so it never exercises the reactive update path.

### Related
Issue 10's search rework eliminates `_RecentFoodsSection` entirely (replaced
by "My Foods" toggle), so this fix may be moot depending on implementation
order.

---

## Issue 2 — Recipe ingredient display formatting

### Root Cause
`RecipeIngredientRow` at `lib/features/recipes/widgets/recipe_ingredient_row.dart:27`:
```dart
subtitle: Text(
  '${ingredient.quantity.toStringAsFixed(1)} × ${food.servingLabel} — ${cals.toStringAsFixed(0)} kcal',
),
```

For per-100g foods (e.g. white rice from OpenFoodFacts with
`servingLabel="100g"`, `servingQuantity=100`), entering 100g produces:
`"100.0 × 100g — 370 kcal"`

The `× servingLabel` suffix is redundant when `quantity == servingQuantity`.

### Existing formatting utilities
`FoodResult.parseServingInfo()` (`lib/core/api/models/food_result.dart:89`)
already has robust logic to extract `(quantity, unit)` tuples from any serving
label format (grams, volume, fractions, parenthetical expressions). This can
be reused or a simpler `_formatServingDisplay(quantity, servingQuantity, servingLabel)` helper can be extracted.

### Fix approach
When `ingredient.quantity == food.servingQuantity`, just display
`food.servingLabel`. Otherwise display `quantity + unit` (derived from the
label or from `servingUnit`). The 2-decimal formatting should also be cleaned
up ("100.00" → "100").

### Test coverage
`test/api/serving_size_parser_test.dart` covers all `parseServingInfo` edge
cases. `test/features/recipes/recipes_test.dart` has no test for the
ingredient row display text.

---

## Issue 3 — History entries missing quantity/unit

### Root Cause
`HistoryScreen` at `lib/features/history/history_screen.dart:299-301`:
```dart
subtitle: Text(
  '${entry.calories.toInt()} cal  •  P...  •  $timeStr',
),
```

The `entry.servingLabel` IS stored in the `food_entries` table (populated by
`_buildLabel()` in `log_food_screen.dart:143-148` and
`quick_food_log_sheet.dart:44-49`). It's just not included in the display.

### Data audit — all save paths populate `servingLabel`
| Save path | File | Serves |
|-----------|------|--------|
| Manual food log | `log_food_screen.dart:185` | `_buildLabel(_servings, _unit)` |
| Quick-log sheet | `quick_food_log_sheet.dart:86` | `_buildLabel(_servings, _unit)` |
| Recipe log | `recipe_provider.dart:62` | `recipe.servingLabel` |
| Edit entry sheet | `edit_entry_sheet.dart:101` | Preserves original `entry.servingLabel` |

All paths do populate it. The display is the only gap.

### Test coverage
`test/features/history/history_screen_test.dart` test helper
`_insertEntry()` always sets `servingLabel: 'serving'`. No test verifies
the real serving label is displayed. The "entry details" test at line 389
only checks for calorie/macro values, not the serving label.

### Fix approach
Add `entry.servingLabel` to the subtitle string on line 301, e.g.:
`'${entry.calories.toInt()} cal • ... • ${entry.servingLabel} • $timeStr'`

---

## Issue 4 — Edit recipes (discoverability)

### Current state — already works
`RecipeFormScreen` already supports `recipeId` mode:
- `_loadRecipe()` at `recipe_form_screen.dart:42` loads all data
- `_save()` at line 200 updates existing recipe + re-inserts ingredients
- `RecipeListScreen._openRecipe()` at `recipe_list_screen.dart:98` navigates
  to `RecipeFormScreen(recipeId:)` on tap

The UX issue is that the recipe card has no **edit icon** — only a delete
button (`Icons.delete_outline`). Users must discover that tapping the card
opens edit mode.

### Fix approach
Add an explicit edit icon button (`Icons.edit`) alongside the delete button
in `_RecipeCard` (`recipe_list_screen.dart:152-186`). Alternatively, ensure
the tap gesture is more clearly indicated (e.g., chevron, tooltip text).

### Test coverage
`test/features/recipes/recipes_test.dart:660-679` tests that edit mode shows
recipe data. No test verifies the edit button exists in the card.

---

## Issue 5 — Duplicate recipes

### Current state — not implemented
No `duplicateRecipe` method exists anywhere. The `deleteRecipe` DAO
(`database.dart:267-269`) has no cascade-delete for ingredients, and
there's no copy/clone functionality.

### Constraints
- `recipes` table has no unique constraint on name (duplicate names allowed)
- No FK cascade — `deleteRecipe` leaves orphaned ingredient rows

### Implementation requirements
1. New DAO method or `RecipeService.duplicateRecipe(int recipeId)`:
   - Read original recipe + ingredients
   - Insert new recipe row (append " (copy)" to name, new timestamps)
   - Copy all ingredients with new `recipeId`
2. UI: duplicate icon on recipe card/list — or a popup menu option

### Files affected
- `lib/core/database/database.dart` — new `duplicateRecipe()` method
- `lib/providers/recipe_provider.dart` — expose via `RecipeService`
- `lib/features/recipes/recipe_list_screen.dart` — add duplicate button
- `test/features/recipes/recipes_test.dart` — new tests

---

## Issue 6 — "Create custom food" placement

### Root Cause
`FoodSearchDelegate._buildContent()` at `food_search_delegate.dart:48-79`:
1. (empty query) `_RecentFoodsSection`
2. "Create custom food" `ListTile`
3. (query) search results

The "Create custom food" row should be first, before recent foods.

### Fix approach
Simple swap — move the "Create custom food" `ListTile` above
`_RecentFoodsSection` in the children list.

### Important note
If Issue 10 (search rework) is implemented, this section becomes irrelevant
since "My Foods" mode always shows "Create custom food" at top and recent
foods are subsumed into the full local list.

---

## Issue 7 — Custom food calorie recalculation

### Root Cause
`ManualFoodForm._autoComputeCalories()` (`manual_food_form.dart:89-112`)
uses a `_caloriesManuallyEdited` flag that, once set (user edits calories
field), permanently blocks all future auto-computations. The flag only resets
when all three macro fields are cleared to zero simultaneously.

### Desired behavior
Every macro field edit should recalculate calories. The user should be able to
manually set calories, but the NEXT macro edit should overwrite the manual
value. The `_caloriesManuallyEdited` concept is wrong.

### Fix approach
Remove the `_caloriesManuallyEdited` flag entirely. The `_settingCalories`
guard already prevents the infinite loop (calories field `onChanged` won't
re-trigger `_autoComputeCalories` because the flag guards against it).

Call `_autoComputeCalories()` unconditionally from each macro's
`onChanged`.

### Files affected
- `lib/features/logging/widgets/manual_food_form.dart`
- `test/features/logging/manual_food_form_test.dart` — update tests that
  verify the old "manual edit blocks auto-compute" behavior

---

## Issue 8 — Delete only from history

### Root Cause
Delete buttons exist in two places:
1. `_TodayEntriesSection` in `log_food_screen.dart:512-518` (trash icon)
2. `HistoryScreen` in `history_screen.dart:240-297` (swipe-to-delete)

The issue says delete should live ONLY in history.

### Fix approach
Remove the trash icon `IconButton` from `_TodayEntriesSection` at line 512.
The `_deleteEntry` method and its helper can remain or be removed.

### Caveat
Issue 15 combines Log + History into a single screen. If done first, this
issue is naturally resolved since there's only one screen and one delete
path.

### Files affected
- `lib/features/logging/log_food_screen.dart` — remove delete from today's entries

---

## Issue 9 — Recent foods uniqueness

### Current code — dedup already implemented
`getRecentFoods()` at `database.dart:185-218`:
1. Fetches ALL food entries where `foodId IS NOT NULL`, ordered by `loggedAt DESC`
2. Iterates with a `seenIds` set → only first occurrence of each `foodId` is kept
3. Looks up the `Food` record for each unique ID

This logic is correct. Duplicate foodIds cannot survive this dedup.

### Possible root cause of reported dupes
The `recentFoodsProvider` uses `ref.read(databaseProvider)` (Issue 1), so it
doesn't auto-refresh. If two different API foods get saved as separate local
rows (rare, but possible if barcode is null), they might appear as distinct
items until the provider refreshes. Or if the `_TodayEntriesSection` displays
entries differently than the search delegate's recent foods section.

### Discovery outcome
The dedup logic in the DAO is already correct. The perceived duplicates were
likely caused by the stale provider cache from Issue 1. The real fix is
making the provider reactive (Issue 1) — or, better, implementing Issue 10's
search rework which eliminates the separate recent-foods concept entirely.

---

## Issue 10 — Food search rework (MAJOR)

### Current architecture
```
FoodSearchDelegate
├── [empty query] → _RecentFoodsSection (recentFoodsProvider)
├── [always] → "Create custom food" ListTile
└── [query] → _DebouncedSearch → FoodSearchService.search()
      ├── local DB (searchByName, like '%query%')
      └── API (OpenFoodFactsClient.search, if local < 25 results)
```

### Requirements
- Toggle: "My Foods" / "Search the Web" (SegmentedButton at top of delegate)
- Default: "My Foods" (local DB only, sorted by recency)
- "My Foods" with empty query → show ALL local foods, sorted by recency
- "My Foods" with query → LIKE search on local DB, sorted by recency
- "Create custom food" ONLY when toggled to "My Foods", always first
- "Search the Web" → direct API call (no local fallback)
- Eliminates separate `_RecentFoodsSection` and `recentFoodsProvider`

### What needs discovery
- **New DAO method needed**: `searchLocalByRecency(query)` that joins
  `foods` with `food_entries` to sort by last-logged date, with optional
  name filter. For empty query, return all foods ordered by recency.

### Files affected
- `lib/features/logging/widgets/food_search_delegate.dart` — major rewrite
- `lib/core/database/database.dart` — new `searchLocalByRecency()` DAO
- `lib/providers/food_search_provider.dart` — update service
- `lib/providers/recent_foods_provider.dart` — likely removable
- `lib/features/recipes/recipe_form_screen.dart` — uses delegate, no change needed

### Test coverage
`test/providers/food_search_provider_test.dart` — needs complete rewrite
`test/features/logging/log_food_screen_test.dart` — update for new search UI

---

## Issue 11 — Brand field (schema change)

### Current schema
`foods` table at `lib/core/database/tables/foods.dart` — 12 columns, no
`brand` column.

### OpenFoodFacts API — brand availability
The API response JSON for a product includes a `brands` field (comma-separated
string of brand names). This is currently ignored by `FoodResult.fromJson()`.

### Files affected
| File | Change |
|------|--------|
| `lib/core/database/tables/foods.dart` | Add `TextColumn get brand => text().nullable()()` |
| `lib/core/database/database.dart` | Schema v3→v4 migration: `ALTER TABLE foods ADD COLUMN brand TEXT` |
| `lib/core/api/models/food_result.dart` | Parse `brands` from JSON, add `brand` field |
| `lib/providers/food_search_provider.dart` | Add `brand` to `FoodSearchItem` |
| All `FoodsCompanion.insert()` call sites | Pass `Value(brand)` parameter |

### Call sites for `FoodsCompanion.insert` (must all add brand):
1. `log_food_screen.dart:162` — API save
2. `quick_food_log_sheet.dart:63` — API save from quick-log
3. `manual_food_form.dart:126` — custom food (brand=null)
4. `food_search_provider.dart:97` — `saveApiResult()`

### Test coverage
None specific to brand. The `FoodResult.fromJson()` parser tests at
`test/api/open_food_facts_client_test.dart` need updating if any tests
verify exact response structure. The `FoodsCompanion` insert tests at
`test/database_test.dart` need to include the new column.

---

## Issue 12 — Edit entry: quantity only

### Current state
`EditEntrySheet` (`edit_entry_sheet.dart`) has editable fields for:
- Name, Qty/Servings, Calories, Protein, Carbs, Fat, Meal type

### Changes needed
- Name, Calories, Protein, Carbs, Fat → read-only display
- Qty/Servings remains editable (with auto-scaling of total macros)
- Meal type remains editable
- The servings listener (`_onServingsChanged` at line 63) continues to work
- Form validation updates accordingly

### Files affected
- `lib/features/history/widgets/edit_entry_sheet.dart`
- `test/features/history/history_screen_test.dart` — update tests that
  change name/macros via edit (lines 188-230, 232-273, 275-322)

### Test impact
Tests "edit save: change name" (188-230) and macro scaling tests (232-322)
will fail because the name/macro fields become read-only. Tests need to
verify that only quantity can be edited.

---

## Issue 13 — Weight assumption for missing days

### Current algorithm
`MaintenanceCalculator.calculate()` (`maintenance_calculator.dart`):
- Collects weight entries from last 30 days
- Requires ≥7 weight entries (returns null otherwise)
- For each weight datapoint, creates a ±3 day sliding window
- Requires ≥3 weight points in window AND ≥3 calorie days in window
- Pairs into (avgCalories, weightSlope) data points
- Requires ≥14 paired points for second regression

The algorithm ALREADY tolerates gaps:
- Windows with <3 weight points are skipped individually
- Calorie days with <3 entries are skipped
- The check is at the window level, not requiring daily weights

### Gap
If a user logs weight on Monday (80kg), then nothing until Friday (81kg),
the Tuesday/Wednesday/Thursday windows either use stale nearby weights or
are skipped entirely if they have <3 weight points. The algorithm doesn't
forward-fill — it only uses actually logged dates.

### Fix approach
Before the regression loop, iterate from `cutoff` to `today`, forward-filling
weights: for each missing date, copy the most recent previous weight entry.
This ensures every day has a weight datapoint, giving more valid windows.

### Alternative (simpler)
Simply increase the window tolerance or decrease the minimum weight points
requirement. But forward-filling is more principled.

### Files affected
- `lib/core/algorithms/maintenance_calculator.dart`
- `test/core/algorithms/maintenance_calculator_test.dart` — add test for
  gap-filling behavior

---

## Issue 14 — Imperial default in onboarding

### Root Cause
`_useImperial = false` at `onboarding_screen.dart:30`

### Fix
Change to `_useImperial = true` (line 30 of `onboarding_screen.dart`).

### No other changes needed
The unit conversion logic (`_onUnitsChanged`) handles both directions
correctly, so changing the default will correctly show imperial fields
(ft/in, lb) on first render.

---

## Issue 15 — Combine Log + History screens (MAJOR)

### Current tab structure
| Tab | Screen | Purpose |
|-----|--------|---------|
| 0 | `DashboardScreen` | Summary dashboard |
| **1** | **`LogFoodScreen`** | **Today's entries + food logging** |
| 2 | `BodyweightScreen` | Weight log + chart |
| **3** | **`HistoryScreen`** | **Paginated all-time history** |
| 4 | `GoalsScreen` | Goal settings |

### New tab structure
| Index | Screen | Notes |
|-------|--------|-------|
| 0 | `DashboardScreen` | Unchanged |
| **1** | **Combined LogScreen** | **History + day nav + log button** |
| 2 | `BodyweightScreen` | Unchanged |
| 3 | `GoalsScreen` | Unchanged |

### New combined Log tab — required features
1. Day navigation: date label with left/right arrows, default to "Today"
2. Entries for selected date, grouped by meal order (breakfast→lunch→dinner→snack)
3. Each entry shows: name, servingLabel, macros, time, meal badge
4. Edit entry (tap) → opens simplified `EditEntrySheet` (quantity-only per Issue 12)
5. Delete entry (swipe or icon) → confirmation dialog
6. "Log new food" button (FAB or pinned bottom button) → opens existing food logging flow
7. CSV export in overflow menu (moved from current History screen)

### What needs discovery — implementation approach

**Data layer:**
- `getEntriesForDate()` at `database.dart:170-179` already works
- Can create `dateFoodProvider(DateTime)` — a `FutureProvider.family` keyed
  by date string, watching `resetTriggerProvider` + `dataTriggerProvider`

**Existing components to reuse:**
- `_groupByMealType()` — can be extracted from `_TodayEntriesSection` in `log_food_screen.dart:438-444`
- `ServingSizePicker`, `MealTypeSelector`, `QuickFoodLogSheet`, `ManualFoodForm`,
  `FoodSearchDelegate` — all reusable from logging widget catalog
- `LogRecipeSheet` — for recipe logging
- `exportFoodEntriesToCsv()`, `shareCsv()`, `saveCsvToDownloads()` — from
  `lib/features/history/export.dart`

**Components to create:**
- `DateNavigator` — day selector widget (date label + prev/next buttons)
- `CombinedLogScreen` — new screen merging all functionality

**Cleanup:**
- `LogFoodScreen` can be deleted or gutted (its food-logging flows become
  modal bottom sheets / pushed routes from the combined screen)
- `HistoryScreen` can be deleted
- `_AppShell` in `app.dart` — remove history tab, relabel log tab, 4 dests

### Files affected
- `lib/app.dart` — new tab structure, new screen references
- `lib/features/logging/log_food_screen.dart` — gut/delete
- `lib/features/history/history_screen.dart` — gut/delete
- `lib/features/history/widgets/edit_entry_sheet.dart` — simplified per Issue 12
- New: `lib/features/logging/combined_log_screen.dart`
- New: day navigation widget
- New: `dateFoodProvider` or similar

### Test impact
- Delete `test/features/history/history_screen_test.dart` (rewrite as
  combined-log tests)
- Update `test/features/logging/log_food_screen_test.dart`
- Update `test/widget_test.dart` (app shell structure)
- Rewrite edit-entry tests for read-only behavior
