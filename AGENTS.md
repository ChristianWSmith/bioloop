# bioloop — AGENTS.md

Flutter macro counter that auto-adjusts daily targets based on bodyweight trends. Uses rolling regression to derive maintenance calories from logged food + weight data.

**Tech stack**: Flutter / drift / Riverpod / OpenFoodFacts API

## Commands

| Action | Command | Notes |
|--------|---------|-------|
| Get dependencies | `flutter pub get` | |
| Analyze (lint) | `flutter analyze > analyze.log 2>&1` | Read `analyze.log` after — do NOT pipe or grep output directly |
| Run tests | `flutter test > test.log 2>&1` | Read `test.log` after — do NOT pipe or grep output directly |
| Run app | `flutter run` | |
| Generate drift code | `dart run build_runner build` | |

**Important:** `flutter analyze` and `flutter test` are slow in this project. Always redirect output to a log file and read the file afterward. Running these commands directly and grepping the output wastes time — they take long enough that it's better to run once, cache the full output, then analyze the cached file.

## Architecture

```
lib/
  main.dart              # ProviderScope, runApp
  app.dart               # MaterialApp + onboarding gate
  theme/
    theme.dart           # AppTheme (light + dark, Material 3)
  core/
    database/
      database.dart      # AppDatabase (drift) — all DAO methods
      tables/            # 6 table definitions (drift .dart files)
    api/
      open_food_facts_client.dart
      models/food_result.dart
    algorithms/
      maintenance_calculator.dart  # rolling linear regression
      mifflin_st_jeor.dart         # BMR estimator
    utils/
      calorie_clamp.dart           # clamp OFF calories to 4-4-9 max
  providers/             # 13 Riverpod providers
  features/
    onboarding/          # first-launch setup flow
    dashboard/           # summary + progress rings + sparkline
    logging/             # food search, log, barcode, macro bars, today's entries
    bodyweight/          # weight log + chart
    history/             # CSV export + edit entry sheet
    goals/               # goal type, calorie adj, sliders
    recipes/             # create/edit/log composite dishes
    settings/            # data reset
```

## Key conventions

### Drift (database)
- 6 tables (schema v1): `foods`, `food_entries`, `bodyweight_entries`, `user_goals`, `recipes`, `recipe_ingredients`
- `foods` table has 13 columns: id, name, servingLabel, servingQuantity (default 1.0), servingUnit (default 'serving'), caloriesPerServing, proteinPerServing, carbsPerServing, fatPerServing, barcode (nullable, unique), brand (nullable), source (default 'manual'), createdAt
- `user_goals` table has 13 columns: id (default 1 singleton), goalType, calorieAdjustment (nullable), proteinGPerLb (default 1.0), fatCaloriePct (default 25.0), sex (nullable), heightCm (nullable), birthdate (nullable), age (nullable), useImperial (default 0), activityLevel (default 3), onboardingCompleted (default 0), updatedAt
- Table definitions in `lib/core/database/tables/` (one file per table)
- All DAO methods on `AppDatabase` in `lib/core/database/database.dart`
- Use `AppDatabase.createInMemory()` for tests
- In-memory DB does NOT enforce FK constraints by default
- No migration strategy implemented yet (schemaVersion = 1, onCreate only)

### Riverpod providers

| Provider | Type | Purpose |
|----------|------|---------|
| `databaseProvider` | `Provider<AppDatabase>` | DB instance (must be overridden) |
| `resetTriggerProvider` | `StateProvider<int>` | Incremented on reset → triggers re-fetch |
| `dataTriggerProvider` | `StateProvider<int>` | Incremented on any data mutation → triggers maintenance refresh |
| `userGoalsProvider` | `FutureProvider<UserGoal?>` | Current goals row |
| `goalsProvider` | `Provider<GoalsService>` | CRUD wrapper for goals |
| `unitPreferencesProvider` | `Provider<UnitPreferences>` | Derived from goals — exposes imperial/metric + conversion helpers |
| `bodyweightProvider` | `FutureProvider<List<BodyweightEntry>>` | All weight entries (desc) |
| `bodyweightServiceProvider` | `Provider<BodyweightService>` | CRUD wrapper for weight entries |
| `foodLogProvider` | `Provider<FoodLogService>` | CRUD wrapper for food entries |
| `todaysFoodProvider` | `FutureProvider<List<FoodEntry>>` | Today's entries (watches resetTrigger + dataTrigger) |
| `dateFoodProvider` | `FutureProvider.family<List<FoodEntry>, DateTime>` | Entries for a specific date |
| `foodSearchServiceProvider` | `Provider<FoodSearchService>` | Local + API search |
| `openFoodFactsClientProvider` | `Provider<OpenFoodFactsClient>` | API HTTP client |
| `macroTargetsProvider` | `FutureProvider<MacroTargets>` | Calculated daily targets |
| `maintenanceProvider` | `FutureProvider<MaintenanceResult?>` | Rolling regression output (watches dataTriggerProvider + resetTriggerProvider); returns non-null result even on failure with `failureReason` set |
| `localFoodListProvider` | `FutureProvider.family<List<FoodSearchItem>, String>` | Local food list by query (watches dataTriggerProvider for reactive refresh after mutations) |
| `onboardingProvider` | `Provider<OnboardingService>` | Onboarding read/write |
| `recipeListProvider` | `FutureProvider<List<Recipe>>` | All recipes |
| `recipeDetailProvider` | `FutureProvider.family<RecipeDetail?, int>` | Single recipe with ingredients + macros |
| `recipeServiceProvider` | `Provider<RecipeService>` | Recipe CRUD + log-recipe helper |

### Widgets / screens
- Every screen is a `ConsumerWidget` or `ConsumerStatefulWidget`
- Screen/widget files in `lib/features/<feature>/`
- Shared widgets in `lib/features/<feature>/widgets/`
- Material 3 throughout; use `Theme.of(context).colorScheme` for colors

### Testing
- Tests in `test/` mirroring the `lib/` structure
- For Drift: `AppDatabase.createInMemory()`, insert seed data, add `addTearDown(() => db.close())`
- For providers: override `databaseProvider` with the in-memory DB
- For widget tests: `pumpWidget(ProviderScope(...))`, `pumpAndSettle()`
- All DB operations inside widget tests (even assertions) work because the in-memory DB is synchronous
- `test/features/logging/search_delegate_test.dart` tests `FoodSearchDelegate` toggle interaction (opening, toggling segments, typing + Enter) and deletion refresh (food disappears from list immediately after delete)

## Design rules

- **Disable, don't validate**: keep submit buttons disabled until all conditions are met (never show validation errors after tap)
- **Errors show dialogs**: network/DB errors show a modal `AlertDialog` (not snackbar or inline text), one "OK" dismiss button
- **Macro targets**: protein/fat sliders physically clamped (protein 0.5–2.0 g/lb, fat 10–50%)
- **Serving math**: all macro formulas normalize by `servingQuantity`: `macroPerServing * (quantity / servingQuantity)`. This handles both per-serving (servingQuantity=1) and per-100g (servingQuantity=100) foods correctly. Zero-division guard: `qty / (sq > 0 ? sq : 1)`
- **Auto-calc calories**: `ManualFoodForm` auto-computes calories from protein/carbs/fat (4-4-9 rule) on every macro field change; a `_caloriesManuallyEdited` flag prevents overwriting user-entered values until all three macro fields are cleared
- **Calorie clamping for OFF imports**: OpenFoodFacts foods are clamped to `min(apiCalories, protein*4 + carbs*4 + fat*9)` before saving to the database. This prevents inflated API calorie values (e.g. 170 cal for 10g carbs + 1g protein = 44 macro cal) from corrupting tracking. Foods with calories below macro-calories (sugar alcohols) are preserved as-is. Applied in `FoodSearchService.saveApiResult()` and `QuickFoodLogSheet._log()`. File: `lib/core/utils/calorie_clamp.dart`
- **Recipe macros**: computed dynamically from ingredients (not stored as snapshots); scale = portion / servingSize
- **Logging a recipe**: creates single `food_entry` with summed macros × scale, sets `recipe_id` FK
- **CSV export**: sync (`compute`), writes to temp dir, shares via `share_plus`
- **Log tab entry delete**: swipe-to-dismiss or delete button per entry in today's list; shows confirmation dialog; increments `dataTriggerProvider` (which `todaysFoodProvider` watches) to refresh the list on success
- **Recipe management**: `RecipeListScreen` has `pickerMode` parameter — management mode (Recipes tab): tap to edit, long-press to delete with haptic feedback; picker mode (Log screen): tap to log recipe only. Single FAB for "new recipe" (AppBar actions button removed). Edit flow re-inserts ingredients after save (bug fix #1). Files: `lib/features/recipes/recipe_list_screen.dart:171-240`, `lib/features/recipes/recipe_form_screen.dart:204-217`
- **Unit filtering for imported foods**: `ServingSizePicker` filters unit dropdown to `[parsedUnit, 'Custom…']` when `source == 'open_food_facts'`. Manual foods show all 11 common units. Prevents confusion from selecting nonsensical units for API-imported foods. File: `lib/features/logging/widgets/serving_size_picker.dart:56-63`
- **Search delegate**: `FoodSearchDelegate` accepts `searchService`, `apiClient` (`OpenFoodFactsClient`), `onCreateCustomFood`, and `onQuickLog` (async); shows a segmented toggle ("My Foods" / "Search the Web") wrapped in `SizedBox(width: double.infinity)` for width stability; `_searchMode` is stored on the delegate field so it survives `buildResults`/`buildSuggestions` rebuilds when Enter is pressed; `_FoodSearchContentState` keeps a local `_localSearchMode` synced via `didUpdateWidget` so the toggle responds even when the search field has focus; `Icons.qr_code_scanner` button in `buildActions` opens `BarcodeScannerScreen`; local search uses `localFoodListProvider` (a `FutureProvider.family` that watches `dataTriggerProvider`) so the list reactively refreshes after mutations; tapping a food list item calls `onQuickLog` (which opens `QuickFoodLogSheet` in-place) instead of selecting it — after the sheet closes, the delegate pops itself via `nav.pop<FoodSearchItem?>(null)`; `onSelectItem` is only used as fallback when `onQuickLog` is null (recipe form path); there is no trailing `+` button (removed — tapping the item does the same thing); "Create custom food" ListTile pops the delegate synchronously after setting the flag
- **Quick-food log sheet**: `QuickFoodLogSheet` in `lib/features/logging/widgets/quick_food_log_sheet.dart` — reusable modal bottom sheet with serving picker, macro preview, meal type selector, and "Log to today" button; supports both fresh quick-log (`food` only) and duplicate (`food` + `sourceEntry` with pre-filled servings); `servingLabel` is saved as just `_unit` (not quantity + unit) so `EditEntrySheet` shows `"g"` instead of `"100 g"` as the quantity suffix
- **Onboarding complete** (`_onOnboardingComplete` in `app.dart`): invalidates `bodyweightProvider`, `todaysFoodProvider`, and `userGoalsProvider` and increments `dataTriggerProvider` so providers re-fetch with the newly saved data
- **Unit preference helpers** (`UnitPreferences` in `unit_preferences_provider.dart`): `displayWeight(double kg)` converts kg→lb, `kgWeight(double display)` converts lb→kg; use `unitPreferencesProvider` instead of reading `useImperial` directly from the DB
- **Data reset**: `resetAll()` truncates all 6 tables in FK-safe order within a transaction; increments `resetTriggerProvider` → `App` re-checks onboarding
- **Maintenance refresh**: `dataTriggerProvider` (StateProvider<int>) is incremented at every bodyweight/food mutation site alongside `ref.invalidate(bodyweightProvider)` / `ref.invalidate(todaysFoodProvider)`. `maintenanceProvider` and `_countDataDaysProvider` (private, in `maintenance_card.dart`) both `ref.watch()` it, making the maintenance estimate reactively refresh.

## Important notes

- `flutter analyze` should always pass with zero issues
- In-memory drift DBs don't enforce foreign keys; rely on explicit delete ordering or explicit cascade deletes in tests
- `databaseProvider` is intentionally un-implemented at declaration site (throws `UnimplementedError`); `main.dart` creates the real DB and overrides it
- Schema version is 1 with onCreate only — no onUpgrade migration strategy implemented yet
- `getRecentFoods()` / `searchLocalByRecency()` in `AppDatabase` fetches distinct `foodId`s from `food_entries` in a Dart-side loop (drift 2.31.0 has no `groupBy` on `SimpleSelectStatement`); orders by `MAX(loggedAt)` DESC, limit 10, then fetches `Food` records from the `foods` table
- Maintenance calculator (`maintenance_provider.dart`) uses `DateTime.now().subtract(const Duration(days: 1))` so the 30-day regression window ends yesterday, excluding today's partial data
- `MaintenanceResult` includes a `MaintenanceFailureReason? failureReason` field (null on success). Reasons: `noWeights` (no weight entries), `insufficientPairedData` (< 10 paired calorie+slope points). Zero regression slope (weight stability) returns average calories as maintenance with infinite confidence interval.
- Minimum paired data threshold is 10 (not 14). `_countDataDaysProvider` progress bar denominator is 10. `MaintenanceCard` shows reason-specific messages instead of a generic "insufficient data" prompt.
- All macro calculations (save, preview, recipe totals, ingredient rows, `computeRecipeMacros()`) use `macroPerServing * (qty / servingQuantity)` with a zero-division guard. When adding new macro math, always use this pattern.
- `_selectFood()` defaults to `_servings = food.servingQuantity` (not 1). This is correct with the formula fix — for per-100g foods, `_servings=100` means `macro * (100/100) = macro`, giving the right display for 1 serving.
- **Recipe ingredient default quantity**: When adding ingredients to a recipe, the quantity defaults to `food.servingQuantity` (not `1`). Both paths (search dialog and custom food form) use `food.servingQuantity` as the default, matching the `_selectFood()` convention.
- `MacroBars` widget at `lib/features/logging/widgets/macro_bars.dart` shows compact macro progress bars on the log screen. Uses calories (primary), protein (blue), carbs (green), fat (orange) colors matching `DashboardScreen`. Consumed totals computed via `.fold()` on `dateFoodProvider(_currentDate)` entries.
- **`macroTargetsProvider`** watches `userGoalsProvider` (a `FutureProvider<UserGoal?>`) instead of `goalsProvider.getGoals()`. This makes it reactive to `GoalsScreen._save()` which invalidates `userGoalsProvider`, so protein/fat goal changes propagate to macro targets without restart.
- **Onboarding discard** uses `SystemNavigator.pop()` (from `package:flutter/services.dart`) instead of `Navigator.pop()` to close the app when the user confirms they want to discard onboarding progress. In widget tests, `SystemNavigator.pop()` is a no-op, so the test asserts the dialog is gone rather than checking for route removal.
- **`DayNavigator`** is a static utility class (`DayNavigator.format(DateTime)`) that returns a formatted date string ("Today", "Yesterday", "Tomorrow", or "Jan 15, 2026"). The chevron buttons live in `AppBar.title` as a `Row(mainAxisSize: MainAxisSize.min)` with the date `Text` between them, and `centerTitle: true` centers the whole group. Only `menu_book` (recipe log) and `PopupMenuButton` (CSV) remain in `actions`.
- **Per-food macro breakdown bars**: `_MacroBreakdownBar` in `combined_log_screen.dart` renders 3 proportional colored segments (blue=protein, green=carbs, orange=fat) using `Expanded(flex:)` based on each macro's calorie contribution (4-4-9 rule). Fills the full `ListTile` width, wrapped in `ClipRRect`. Zero-total food returns `SizedBox.shrink()`. Zero-value segments use `clamp(1, 9999)`.
- **Log screen entry display**: Each food entry's `ListTile` subtitle is the `_MacroBreakdownBar` (no macro text or time). Trailing is bold `"XXX cal"` text (meal-type badge removed). Section headers have a 3px colored left border strip, meal-type icon (`Icons.free_breakfast`/`Icons.lunch_dining`/`Icons.dinner_dining`/`Icons.cookie`), bold colored heading, and tinted count badge.
- **Maintenance forward-fill**: `MaintenanceCalculator.calculate()` assumes the oldest logged weight for all dates before the first weight entry. This ensures new users with sparse early data can get maintenance estimates. Example: If you onboard at 190 lbs on May 16, the algorithm assumes you were 190 lbs for all dates in the 30-day window before May 16. If you delete the May 16 weight, the assumption shifts to the new oldest weight. File: `lib/core/algorithms/maintenance_calculator.dart:57-78`
- **Recipe edit bug fix**: When editing a recipe, the save logic re-inserts ingredients after deleting them. Previously, ingredients were deleted but not re-inserted, causing zero macros. File: `lib/features/recipes/recipe_form_screen.dart:204-217`
