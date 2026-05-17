# Discovery — Issues Analysis

## Issue 1: Calorie clamping for OpenFoodFacts imports

### Problem
OpenFoodFacts API returns foods with calorie values that don't match the 4-4-9 macro calculation. Example: 10g carbs + 1g protein + 0g fat = 44 cal from macros, but API reports 170 cal. These inflated values enter the local database unchecked.

### Root Cause
No validation or clamping exists anywhere in the OpenFoodFacts import path. Values pass through from the API → `FoodResult.fromJson()` → `FoodSearchItem` → `db.insertFood()` with zero transformation.

### Affected Code Paths

| File | Function | Lines | Description |
|------|----------|-------|-------------|
| `lib/core/api/models/food_result.dart` | `FoodResult.fromJson()` | 30-82 | Parses API JSON; no validation |
| `lib/providers/food_search_provider.dart` | `FoodSearchService.saveApiResult()` | 105-120 | Saves to DB via `insertFood()`; no clamping |
| `lib/features/logging/widgets/quick_food_log_sheet.dart` | `_QuickFoodLogSheetState._log()` | 57-72 | Inline insert when logging an OFF food with no `localId`; no clamping |

### Save Flow
```
OpenFoodFacts API → FoodResult.fromJson() → FoodSearchItem.fromFoodResult()
  → User taps item → QuickFoodLogSheet displayed
    → User presses "Log entry" → _log()
      → if food.localId == null && source == 'open_food_facts':
          db.insertFood(FoodsCompanion.insert(caloriesPerServing: food.caloriesPerServing, ...))
          ^^^ NO CLAMPING
```

### Design Decision
Clamp to `min(apiCalories, macroCalories)` where `macroCalories = protein*4 + carbs*4 + fat*9`. This allows calories to be *less* than macro calories (sugar alcohols, fiber) but never more. The 4-4-9 rule gives the theoretical maximum calories from macros; anything above is clearly erroneous data.

### Implementation Plan
1. Create `lib/core/utils/calorie_clamp.dart` with `clampCaloriesToMacros({required double calories, required double protein, required double carbs, required double fat}) → double`
2. Call it in `FoodSearchService.saveApiResult()` before `db.insertFood()` (`food_search_provider.dart:106`)
3. Call it in `QuickFoodLogSheet._log()` inline insert (`quick_food_log_sheet.dart:58-71`)
4. Add unit tests: normal case, over-inflated, under-calculated (sugar alcohols), zero macros, negative guard

---

## Issue 2: Duplicate "add new" button on recipe screen

### Problem
`RecipeListScreen` has two identical "add new" buttons: one in `AppBar.actions` (top right) and one `FloatingActionButton` (bottom center).

### Root Cause
Both buttons were added independently and do the exact same thing: push `RecipeFormScreen` and invalidate `recipeListProvider` on success.

### Affected Code
`lib/features/recipes/recipe_list_screen.dart`:
- AppBar button: lines 24-39
- FAB: lines 41-55

### Implementation Plan
1. Remove the `actions: [...]` block from the `AppBar` (lines 24-39)
2. Keep the FAB (standard Flutter pattern for primary create actions)
3. Update the empty-state text "Tap + to create one." (line 70) — it references "+", which now only exists on the FAB, so this is still accurate
4. No test changes expected (no tests reference the AppBar button)

---

## Issue 3: Deleted food doesn't disappear from "My Foods" list

### Problem
After deleting a food from the search screen while on "My Foods" tab, the deleted food remains visible until the user leaves and re-enters the search screen.

### Root Cause
`_LocalSearchContent` (`food_search_delegate.dart:197-338`) uses a `FutureBuilder` that calls `searchService.searchLocal(query)` directly in its `build` method. The `FutureBuilder` caches its future result. After deletion:

1. `_deleteFood` in `combined_log_screen.dart:121-171` calls `db.deleteFood(food.id)`
2. It increments `dataTriggerProvider` and invalidates `todaysFoodProvider`
3. But `_LocalSearchContent` is a `StatelessWidget` with a `FutureBuilder` that does **not** watch `dataTriggerProvider`
4. The `FutureBuilder`'s future has already resolved with the old data
5. No `setState()` is called on `_FoodSearchContentState` after deletion completes
6. The widget tree doesn't rebuild in a way that causes the `FutureBuilder` to re-evaluate

The deletion callback is `await`ed (`food_search_delegate.dart:275` and `:324`), but after the await completes, the `FutureBuilder` still holds its cached snapshot. The `SearchDelegate` framework doesn't trigger a rebuild of `buildResults`/`buildSuggestions` after an async callback completes within the content.

### Key Files
| File | Component | Lines |
|------|-----------|-------|
| `lib/features/logging/widgets/food_search_delegate.dart` | `_LocalSearchContent` (FutureBuilder) | 197-338 |
| `lib/features/logging/widgets/food_search_delegate.dart` | `_FoodSearchContentState` | 137-195 |
| `lib/features/logging/combined_log_screen.dart` | `_deleteFood` handler | 121-171 |
| `lib/providers/food_search_provider.dart` | `FoodSearchService.searchLocal()` | 88-91 |
| `lib/core/database/database.dart` | `db.deleteFood()` (cascade) | 141-146 |
| `lib/core/database/database.dart` | `searchLocalByRecency()` | 204-241 |

### Implementation Options

**Option A: Convert to Riverpod provider (recommended)**
- Create `localFoodListProvider` as a `FutureProvider.family<List<FoodSearchItem>, String>` that watches `dataTriggerProvider`
- Replace `FutureBuilder` in `_LocalSearchContent` with `ref.watch()` + `.when()`
- `_LocalSearchContent` becomes a `ConsumerWidget`
- After deletion, `dataTriggerProvider` is already incremented → provider auto-refreshes
- Pros: Consistent with app's Riverpod architecture, automatic reactivity
- Cons: Requires converting a `StatelessWidget` to a `ConsumerWidget` and threading `WidgetRef` through

**Option B: Add a refresh key (minimal change)**
- Add `int refreshKey` field to `_LocalSearchContent`
- Wrap the `FutureBuilder` with `ValueKey(refreshKey)`
- After `onDeleteFood` completes, call a callback that increments the key
- Requires making `_LocalSearchContent` stateful or adding a callback
- Pros: Minimal code change
- Cons: Ad-hoc pattern, doesn't leverage existing Riverpod infrastructure

**Option C: Call setState on parent after deletion**
- Wrap the `onDeleteFood` call in `_LocalSearchContent` to also trigger a rebuild
- Problem: `_LocalSearchContent` is a `StatelessWidget`, can't call `setState`
- Would need to convert to `StatefulWidget`

**Recommended: Option A** — it aligns with the app's existing Riverpod patterns and the `dataTriggerProvider` mechanism is already designed for this exact purpose (reactive refresh on data mutations).

### Implementation Plan (Option A)
1. Create `lib/providers/local_food_list_provider.dart`:
   ```dart
   final localFoodListProvider = FutureProvider.family<List<FoodSearchItem>, String>((ref, query) async {
     ref.watch(dataTriggerProvider);
     final service = ref.watch(foodSearchServiceProvider);
     return service.searchLocal(query);
   });
   ```
2. Convert `_LocalSearchContent` from `StatelessWidget` to `ConsumerWidget`
3. Replace `FutureBuilder` with `ref.watch(localFoodListProvider(query).when(...))`
4. No changes needed to `_deleteFood` — it already increments `dataTriggerProvider`
5. Add a widget test verifying the list refreshes after deletion

---

## Issue 4: Regression algorithm never kicks in

### Problem
The rolling regression maintenance calculator never produces a result for real-world user data. The user logged food far below maintenance for 14 days AND added daily bodyweight entries, but the algorithm returned null and fell back to Mifflin-St Jeor.

### Root Cause — CONFIRMED

Through diagnostic testing, the exact failure mode has been identified:

**Gate hit: Line 173 — `denom2.abs() < 1e-10`**

The second-level regression computes `weightSlope = rSlope * avgCalories + rIntercept`. The denominator is:
```
denom2 = np * sum(avgCals²) - sum(avgCals)²
```
This is `np² * variance(avgCals)`. When all `avgCals` values are identical (constant daily calorie intake), `denom2 = 0` and the algorithm returns null.

### Diagnostic Results

| Scenario | Result |
|----------|--------|
| 14 days constant 1200 cal + 14 days daily weight | **NULL** (denom2 = 0.0) |
| 14 days varied calories (800-1600) + 14 days daily weight | 715 cal (n=15) |
| 30 days varied food + 14 days weight (last 14 only) | 1385 cal (n=31) |
| Constant calories, any variance amount | NULL |
| ±10 cal variance | 1176 cal (n=15) |
| ±200 cal variance | 715 cal (n=15) |

**Key finding**: The algorithm requires calorie variance to function. This is mathematically necessary — you cannot determine the relationship between calorie intake and weight change if calorie intake never varies. However, the algorithm provides **zero feedback** to the user about why it failed.

### All Early-Return Gates

| # | Line | Condition | Practical Meaning |
|---|------|-----------|-------------------|
| 1 | 98 | `recentWeights.length < 7` | No weight entries (or < 7 after forward-fill) |
| 2 | 126 | `xs.length < 3` | 7-day window has < 3 days (shouldn't happen with forward-fill) |
| 3 | 138 | `denom.abs() < 1e-10` | Weight regression denominator ≈ 0 (shouldn't happen with forward-fill) |
| 4 | 152 | `calDays < 3` | < 3 food-logged days in a 7-day window |
| 5 | 158 | `pairedAvgCals.length < 14` | < 14 paired (calories, slope) data points |
| 6 | 173 | `denom2.abs() < 1e-10` | **No calorie variance** — all daily averages identical |
| 7 | 176 | `rSlope.abs() < 1e-10` | No correlation between calories and weight change |

### Forward-Fill Analysis

The forward-fill logic (lines 65-93) fills every day in the 30-day window:
- Dates before the first weight entry → use `oldestWeight` (flat region)
- Dates after the first weight → use last-known weight (forward-fill)

With 14 weight entries starting 14 days ago:
- 18 days are flat (all same `oldestWeight`)
- 14 days have actual weight data

This produces 31 forward-filled weight entries. The rolling 7-day windows centered on the flat region produce slopes of 0, but the windows centered on the actual weight-change region produce non-zero slopes. The paired point count (15) passes gate 5.

### The Real Problem

The algorithm is mathematically correct but has two UX problems:

1. **No diagnostic feedback**: When it returns null, the UI shows "insufficient data" with a generic progress bar. The user has no idea whether the issue is constant calories, constant weight, insufficient days, or something else.

2. **Constant calories is a common pattern**: Many users eat similar meals day-to-day, especially when trying to cut. The algorithm silently fails for these users.

### Implementation Plan

**Part A: Add diagnostic information to the result**

1. Create a `MaintenanceDiagnostic` enum or sealed class:
   ```dart
   enum MaintenanceFailureReason {
     noWeights,
     insufficientPairedData,
     noCalorieVariance,
     noWeightVariance,
     noCorrelation,
   }
   ```

2. Change `MaintenanceCalculator.calculate()` to return a result that includes the failure reason when null:
   ```dart
   class MaintenanceResult {
     final double? maintenanceCalories;  // null if failed
     final double confidenceInterval;
     final int dataPoints;
     final MaintenanceFailureReason? failureReason;  // null if success
   }
   ```
   Or use a sealed class approach:
   ```dart
   sealed class MaintenanceOutcome {}
   class MaintenanceSuccess extends MaintenanceOutcome { ... }
   class MaintenanceFailure extends MaintenanceOutcome {
     final MaintenanceFailureReason reason;
     final int dataPoints;  // how many paired points were collected
   }
   ```

3. Update `maintenanceProvider` to pass through the diagnostic info.

4. Update `MaintenanceCard` UI to show a specific message based on the failure reason:
   - `noCalorieVariance` → "Log different calorie amounts on different days"
   - `noWeightVariance` → "Your weight hasn't changed — keep logging"
   - `insufficientPairedData` → "X/14 days logged" (existing behavior)
   - `noCorrelation` → "Keep logging — need more data to find the pattern"

**Part B: Lower the paired data threshold**

Change `pairedAvgCals.length < 14` to `< 10` (line 158). With 10 paired points, the regression is still meaningful but achievable for newer users. The existing tests that expect null at 10 data points will need updating.

**Part C: Add a small noise fallback for near-zero variance**

If `denom2.abs() < 1e-10` but `pairedAvgCals.length >= 10`, instead of returning null, add a tiny amount of synthetic variance (e.g., ±0.1 cal) to break the degeneracy and produce a result. This is a pragmatic workaround for users who eat the same thing daily. The confidence interval will be very wide, reflecting the low certainty.

Alternatively, skip this and rely on Part A's diagnostic messaging to guide the user.

**Part D: Update tests**

| Test File | Change |
|-----------|--------|
| `test/core/algorithms/maintenance_calculator_test.dart` | Update "insufficient data — 10 data points returns null" test if threshold changes; add tests for new diagnostic reasons |
| `test/providers/macro_targets_provider_test.dart` | No changes needed (tests the provider cascade, not the calculator internals) |

### Files to Modify

| File | Change |
|------|--------|
| `lib/core/algorithms/maintenance_calculator.dart` | Add diagnostic enum, change return type, lower threshold, add failure reason tracking |
| `lib/providers/maintenance_provider.dart` | Pass through diagnostic info |
| `lib/features/dashboard/widgets/maintenance_card.dart` | Show specific messages based on failure reason; update `_countDataDaysProvider` if needed |
| `lib/providers/macro_targets_provider.dart` | Handle new return type (check for success vs failure) |
| `test/core/algorithms/maintenance_calculator_test.dart` | Update tests, add new diagnostic tests |
| `AGENTS.md` | Update forward-fill documentation and maintenance behavior notes |

---

## Summary of All Changes by File

| File | Issue(s) | Change Type |
|------|----------|-------------|
| `lib/core/utils/calorie_clamp.dart` | #1 | New file |
| `lib/providers/food_search_provider.dart` | #1 | Call clamp in `saveApiResult()` |
| `lib/features/logging/widgets/quick_food_log_sheet.dart` | #1 | Call clamp in inline insert |
| `test/core/utils/calorie_clamp_test.dart` | #1 | New test file |
| `lib/features/recipes/recipe_list_screen.dart` | #2 | Remove AppBar actions button |
| `lib/providers/local_food_list_provider.dart` | #3 | New provider |
| `lib/features/logging/widgets/food_search_delegate.dart` | #3 | Convert to ConsumerWidget, use ref.watch |
| `lib/core/algorithms/maintenance_calculator.dart` | #4 | Add diagnostics, lower threshold |
| `lib/providers/maintenance_provider.dart` | #4 | Pass through diagnostics |
| `lib/features/dashboard/widgets/maintenance_card.dart` | #4 | Show specific failure messages |
| `lib/providers/macro_targets_provider.dart` | #4 | Handle new return type |
| `test/core/algorithms/maintenance_calculator_test.dart` | #4 | Update/add tests |
| `AGENTS.md` | #4 | Update documentation |
