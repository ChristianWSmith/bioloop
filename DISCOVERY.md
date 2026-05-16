# Discovery Report

Compiled from codebase exploration against `issues.txt`.

---

## Issue 1: Long press to delete logged food entries

**Statement**: "the user should be able to long press logged food entries to delete them (with a confirmation)"

### Current behavior
Food entries in `combined_log_screen.dart` are wrapped in a `Dismissible` widget (line 362) that allows swipe-to-dismiss with a confirmation dialog. The inner `ListTile` (line 395) has:
- `onTap: () => _editEntry(entry)` — opens edit sheet
- **No `onLongPress`** — nothing happens on long press

### Existing deletion infrastructure
The `_deleteEntry()` method at line 115–159 handles:
1. Confirmation `AlertDialog` with Cancel/Delete buttons
2. DB delete via `ref.read(foodLogProvider).deleteEntry(entry.id)`
3. `dataTriggerProvider` increment for reactive refresh
4. Error `AlertDialog` with OK dismiss

### Pattern already exists for bodyweight
`bodyweight_screen.dart:111` — bodyweight entries use `onLongPress: () => _confirmDelete(context, ref, entry)` with the same confirmation dialog pattern. This is the exact pattern to replicate.

### Action needed
Add `onLongPress: () => _deleteEntry(entry)` to the `ListTile` at `combined_log_screen.dart:412` (alongside the existing `onTap`).

---

## Issue 2: Long press to delete recipes

**Statement**: "the user should be able to long press recipes to delete them (with a confirmation)"

### Current behavior
**Already implemented** in `recipe_list_screen.dart:217`:
```dart
onLongPress: pickerMode ? null : onDelete,
```
The `onDelete` callback (line 89) calls `_deleteRecipe(context, ref, recipe)` at line 126, which shows a confirmation dialog with Cancel/Delete. Delete also exists as a trash icon button (line 209-213).

### Data integrity bug
The `_deleteRecipe()` method at line 126 calls `db.deleteRecipe(recipe.id)` which performs:
```dart
// database.dart:309-311
Future<void> deleteRecipe(int id) async {
  await (delete(recipes)..where((r) => r.id.equals(id))).go();
}
```
This deletes **only the recipe row** — it does NOT cascade-delete `recipe_ingredients` rows. The dialog promises:
```dart
content: Text('Delete "${recipe.name}" and all its ingredients?'),
```
But `recipe_ingredients` rows are orphaned. The `deleteIngredientsForRecipe()` method exists (`database.dart:378-381`) but is only called during recipe save/update (`recipe_form_screen.dart:214`), never during deletion.

### Action needed
Fix `_deleteRecipe()` to call `db.deleteIngredientsForRecipe(recipe.id)` before `db.deleteRecipe(recipe.id)` (or embed cascade in the DAO).

---

## Issue 3: Web search intermittent failures

**Statement**: "for some reason searching the web in the food search screen intermittently fails. this could be the fault of the openfoodfacts API. we should add in some silent retries in case we fail a search. the user shouldnt know when a retry occurs. we should also differentiate the message when there's no results vs when the search failed."

### Current behavior — API client (`open_food_facts_client.dart`)

The `search()` method (lines 20-48) catches every failure and silently returns `[]`:

| Failure mode | Handling |
|---|---|
| HTTP 429 (rate limit) | Returns `[]` — no retry |
| HTTP non-200 | Returns `[]` — no retry |
| `SocketException` | Caught → returns `[]` |
| `HttpException` | Caught → returns `[]` |
| `FormatException` (bad JSON) | Caught → returns `[]` |
| Timeout (10s) | Throws `TimeoutException` — **not caught**, propagates up |
| Body null / products null | Returns `[]` |

**No retry logic exists. No logging on failure (except debugPrint in the UI layer).**

### Current behavior — service layer (`food_search_provider.dart`)

`FoodSearchService.searchWeb()` (line 82) is a thin wrapper:
```dart
Future<List<FoodSearchItem>> searchWeb(String query) async {
  if (query.trim().isEmpty) return [];
  final results = await apiClient.search(query);
  return results.map(FoodSearchItem.fromFoodResult).toList();
}
```
It cannot distinguish between "search succeeded, no results" and "search failed" because `apiClient.search()` returns `[]` for both.

### Current behavior — UI (`food_search_delegate.dart`)

`_WebSearchContent` at line 307 uses a `FutureBuilder`:
- **Waiting**: `CircularProgressIndicator` (line 312)
- **Error** (`.hasError`): Shows raw `'Error: ${snapshot.error}'` as text (line 321)
  - This path is reached when `searchWeb()` throws an exception (e.g., `TimeoutException` from the 10s timeout, which is NOT caught by the client)
- **Empty data** (`items.isEmpty`): Shows `'No results found'` (line 328)
  - This path is reached for both "no results from API" AND "API returned `[]` due to network failure" — **they are indistinguishable**

### Additional issue: TimeoutException is uncaught
The `TimeoutException` from the `.timeout(10s)` call in `OpenFoodFactsClient.search()` (line 27) is **not** caught by the `on SocketException` / `on HttpException` / `on FormatException` handlers. It propagates up to `_WebSearchContent`'s `FutureBuilder` where it shows as `'Error: TimeoutException...'`.

### Actions needed
1. Add retry logic to `OpenFoodFactsClient.search()`:
   - Retry on: network errors (`SocketException`, `HttpException`, `TimeoutException`), 429, 5xx
   - Do NOT retry on: 4xx (other than 429), `FormatException`
   - Max 2 retries with exponential backoff (e.g., 500ms, 1s)
   - Keep retry transparent — no logging or UI indication
2. Fix the uncaught `TimeoutException` — either catch it in the client or expand the catch clauses
3. Make `searchWeb()` return a result type that distinguishes success from failure (or alternatively, let errors propagate and handle them in the UI layer)
4. Update `_WebSearchContent` to show:
   - `'No results found'` — when search definitely succeeded but returned nothing
   - `'Search failed. Tap to retry.'` — when all retries exhausted

---

## Issue 4: Bodyweight delete shows raw timestamp

**Statement**: "when deleting bodyweight entries, the confirmation prompt uses a raw timestamp. It should probably just be formatted the same way that it is on the bodyweight entry itself"

### Current behavior

In `bodyweight_screen.dart:126-172`, the `_confirmDelete()` method:
```dart
content: Text(
    'Delete weight $displayWeight ${prefs.weightUnit} from ${entry.loggedAt}?'),
```
Uses `entry.loggedAt` directly — the raw database string.

### How the list display formats it (lines 100-104):
```dart
final date = DateTime.parse(entry.loggedAt);
final dateStr =
    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
```

### Why it's a problem
`loggedAt` is a `TextColumn` in the database (`bodyweight_entries.dart:6`). `AddWeightSheet` stores it as `YYYY-MM-DD` (line 57), so currently both the dialog and list show the same format. But:
- The dialog uses the raw field directly
- The list parses it with `DateTime.parse()` and reformats
- If the storage format ever changes, they'd diverge
- It violates the "use the same representation" principle

### Action needed
Apply the same `DateTime.parse` + manual `YYYY-MM-DD` formatting in the dialog's content text. Could also extract a `_formatDate(String loggedAt)` helper to share between `_buildEntry` and `_confirmDelete`.

---

## Issue 5: Remove bodyweight goal entirely

**Statement**: "we should just get rid of bodyweight goal entirely, it's not really that interesting or useful for the scope of this app"

### Where `goalWeightKg` is used

#### 1. Database — `user_goals` table (`tables/user_goals.dart:13`)
```dart
RealColumn get goalWeightKg => real().nullable()();
```
Stored as nullable real in the singleton `user_goals` table (schema v4). Not referenced by any FK.

#### 2. Onboarding screen (`onboarding_screen.dart`)
| Lines | What |
|---|---|
| 30 | `final _goalWeightController = TextEditingController();` |
| 55 | `_goalWeightController.dispose();` |
| 137-139 | Unit toggle conversion (kg→lb) |
| 156-158 | Unit toggle conversion (lb→kg) |
| 190-194 | `_save()` reads controller, converts to kg |
| 207-209 | `_save()` writes `goalWeightKg: Value<double?>` |
| 449-466 | UI section "Goal Weight" with `TextFormField` |

#### 3. Goals screen (`goals_screen.dart`)
| Lines | What |
|---|---|
| 28 | `final _goalWeightController = TextEditingController();` |
| 58 | `_goalWeightController.dispose();` |
| 79-86 | Load: reads `goals.goalWeightKg`, populates controller |
| 215-218 | Unit toggle conversion (kg→lb) |
| 230-233 | Unit toggle conversion (lb→kg) |
| 253-257 | `_save()` reads controller, converts to kg |
| 270-271 | `_save()` writes `goalWeightKg: Value<double?>` |
| 437-452 | UI: `TextFormField` with label "Goal weight (optional)" |

#### 4. Dashboard screen (`dashboard_screen.dart`)
| Lines | What |
|---|---|
| 81-87 | Conditional render: `if (goals?.goalWeightKg != null && latestWeight != null)` → `_buildGoalWeightCard()` |
| 224-289 | `_buildGoalWeightCard()` — shows "current → goal (delta)" or "You reached your goal!" |

#### 5. Tests (18 references across 4 files)
| Test file | References |
|---|---|
| `test/widget_test.dart` | Lines 201, 243, 954 — seed data assertions |
| `test/features/goals/goals_screen_test.dart` | Line 311 — checks saved goal weight |
| `test/database_test.dart` | Lines 196-202 — test `goal_weight_kg is null by default` |
| `test/features/dashboard/dashboard_screen_test.dart` | Lines 168, 180, 190, 195, 244, 273, 302, 315, 377, 437, 546 — seed data + assertions |
| `test/providers/macro_targets_provider_test.dart` | Line 33 — just null in seed data |

#### 6. NOT used in calculations
`goalWeightKg` is **not** referenced in:
- `maintenance_calculator.dart` — only uses food entries + bodyweight entries
- `macro_targets_provider.dart` — only uses `calorieAdjustment`, `proteinGPerLb`, `fatCaloriePct`
- `mifflin_st_jeor.dart` — only uses sex, weight, height, age, activity level

### Schema migration notes
Current schema version: 4 (line 29 of `database.dart`). Existing migrations (lines 37-67):
- v1→v2: Add `serving_unit`, `serving_quantity` to `foods`
- v2→v3: Drop `serving_size_grams` from `foods`
- v3→v4: Add `brand` to `foods`

Adding v4→v5: `ALTER TABLE user_goals DROP COLUMN goalWeightKg`

### Actions needed (Option A: Full DB cleanup)
1. `user_goals.dart` — remove `goalWeightKg` column
2. `database.dart` — add `schemaVersion = 5`, add `if (from < 5) await m.deleteColumn(userGoals, userGoals.goalWeightKg)` to migration
3. `onboarding_screen.dart` — remove `_goalWeightController`, conversion logic (lines 137-139, 156-158), save logic (lines 190-194, 207-209), and UI section (lines 449-466)
4. `goals_screen.dart` — remove `_goalWeightController`, conversion logic (lines 215-218, 230-233), save logic (lines 253-257, 270-271), and UI field (lines 437-452)
5. `dashboard_screen.dart` — remove conditional render (lines 81-87) and `_buildGoalWeightCard()` method (lines 224-289)
6. Update all test files
7. Run `dart run build_runner build` to regenerate drift code

---

## Issue 6: Log food items to the day being viewed

**Statement**: "when logging food items, we should log them to the day we're currently viewing in the log tab. this would be useful if a user remembers a food that they forgot to log on a previous day"

### Current behavior — date navigation

`CombinedLogScreen` has `_currentDate` state (line 26) initialized to today (line 46-48). Chevron buttons (lines 200-211) navigate ±1 day. The `_currentDate` drives the display filter via `dateFoodProvider(_currentDate)` (line 191).

**The `_currentDate` is ONLY used for viewing/filtering.** It is never passed to any logging function.

### Current behavior — logging paths

Both logging paths hardcode `DateTime.now()`:

**Path A: QuickFoodLogSheet** (`quick_food_log_sheet.dart:50`)
```dart
final now = DateTime.now().toIso8601String();
// ...
loggedAt: now,
```
Called from `CombinedLogScreen._showQuickLogSheet()` (line 87-93) — no date parameter.

**Path B: RecipeService.logRecipe()** (`recipe_provider.dart:52`)
```dart
final now = DateTime.now().toIso8601String();
// ...
loggedAt: now,
```
Called from `LogRecipeSheet._log()` (line 35) — no date parameter. `LogRecipeSheet` is created in:
- `recipe_form_screen.dart:268` (from recipe form's "Log this recipe" button)
- `recipe_list_screen.dart:107` (from recipe list picker mode)

### Data model
`food_entries.loggedAt` is a `TextColumn` storing ISO 8601 strings. Date filtering uses `LIKE 'YYYY-MM-DD%'` (database.dart:177).

### Action needed
1. Add optional `DateTime? loggedAt` parameter to `QuickFoodLogSheet` (default `null` → use `DateTime.now()`)
2. Add optional `DateTime? loggedAt` parameter to `LogRecipeSheet` (default `null` → use `DateTime.now()`)
3. Add optional `DateTime? loggedAt` parameter to `RecipeService.logRecipe()` (default `null` → use `DateTime.now()`)
4. Update button text from `'Log to today'` to `'Log entry'`
5. Thread `_currentDate` through the call chain:
   - `CombinedLogScreen._showQuickLogSheet()` → pass `_currentDate`
   - `CombinedLogScreen._onLogRecipe()` → `RecipeListScreen(pickerMode: true, loggedAt: _currentDate)` → `LogRecipeSheet(detail: detail, loggedAt: loggedAt)` → `recipeServiceProvider.logRecipe(loggedAt: loggedAt)`

---

## Summary of all affected files

| File | Issues |
|------|--------|
| `lib/features/logging/combined_log_screen.dart` | 1, 6 |
| `lib/features/logging/widgets/quick_food_log_sheet.dart` | 6 |
| `lib/features/logging/widgets/food_search_delegate.dart` | 3 |
| `lib/features/recipes/recipe_list_screen.dart` | 2, 6 |
| `lib/features/recipes/widgets/log_recipe_sheet.dart` | 6 |
| `lib/features/recipes/recipe_form_screen.dart` | 6 |
| `lib/features/bodyweight/bodyweight_screen.dart` | 4 |
| `lib/features/onboarding/onboarding_screen.dart` | 5 |
| `lib/features/goals/goals_screen.dart` | 5 |
| `lib/features/dashboard/dashboard_screen.dart` | 5 |
| `lib/core/database/database.dart` | 2, 5 |
| `lib/core/database/tables/user_goals.dart` | 5 |
| `lib/core/api/open_food_facts_client.dart` | 3 |
| `lib/providers/food_search_provider.dart` | 3 |
| `lib/providers/recipe_provider.dart` | 6 |
| `test/api/open_food_facts_client_test.dart` | 3 |
| `test/widget_test.dart` | 5 |
| `test/features/goals/goals_screen_test.dart` | 5 |
| `test/features/dashboard/dashboard_screen_test.dart` | 5 |
| `test/database_test.dart` | 5 |
| `test/providers/macro_targets_provider_test.dart` | 5 |
