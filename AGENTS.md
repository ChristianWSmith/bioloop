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
  providers/             # 12 Riverpod providers
  features/
    onboarding/          # first-launch setup flow
    dashboard/           # summary + progress rings + sparkline
    logging/             # food search, log, barcode, today's entries
    bodyweight/          # weight log + chart
    history/             # paginated entry list + CSV export
    goals/               # goal type, calorie adj, sliders
    recipes/             # create/edit/log composite dishes
    settings/            # data reset
```

## Key conventions

### Drift (database)
- 6 tables (schema v2): `foods`, `food_entries`, `bodyweight_entries`, `user_goals`, `recipes`, `recipe_ingredients`
- `foods` table has 13 columns: id, name, servingLabel, servingSizeGrams (nullable), servingQuantity (default 1.0), servingUnit (default 'serving'), caloriesPerServing, proteinPerServing, carbsPerServing, fatPerServing, barcode (nullable, unique), source (default 'manual'), createdAt
- Table definitions in `lib/core/database/tables/` (one file per table)
- All DAO methods on `AppDatabase` in `lib/core/database/database.dart`
- Use `AppDatabase.createInMemory()` for tests
- In-memory DB does NOT enforce FK constraints by default

### Riverpod (12 providers)
| Provider | Type | Purpose |
|----------|------|---------|
| `databaseProvider` | `Provider<AppDatabase>` | DB instance (must be overridden) |
| `resetTriggerProvider` | `StateProvider<int>` | Incremented on reset → triggers re-fetch |
| `userGoalsProvider` | `FutureProvider<UserGoal?>` | Current goals row |
| `unitPreferencesProvider` | `Provider<UnitPreferences>` | Derived from goals — exposes imperial/metric + conversion helpers |
| `bodyweightProvider` | `FutureProvider<List<BodyweightEntry>>` | All weight entries (desc) |
| `foodLogProvider` | `Provider<FoodLogService>` | CRUD wrapper for food entries |
| `todaysFoodProvider` | `FutureProvider<List<FoodEntry>>` | Today's entries (watches resetTrigger) |
| `foodSearchServiceProvider` | `Provider<FoodSearchService>` | Local + API search |
| `foodSearchProvider` | `FutureProvider.family` | Per-query search results |
| `recentFoodsProvider` | `FutureProvider<List<RecentFoodItem>>` | Last 10 distinct foods by recency |
| `macroTargetsProvider` | `FutureProvider<MacroTargets>` | Calculated daily targets |
| `maintenanceProvider` | `FutureProvider<MaintenanceResult?>` | Rolling regression output |
| `onboardingProvider` | (in feature) | Onboarding state |
| `recipeProvider` | (in feature) | Recipe CRUD |

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

## Design rules

- **Disable, don't validate**: keep submit buttons disabled until all conditions are met (never show validation errors after tap)
- **Errors show dialogs**: network/DB errors show a modal `AlertDialog` (not snackbar or inline text), one "OK" dismiss button
- **Macro targets**: protein/fat sliders physically clamped (protein 0.5–2.0 g/lb, fat 10–50%)
- **Serving math**: all macro formulas normalize by `servingQuantity`: `macroPerServing * (quantity / servingQuantity)`. This handles both per-serving (servingQuantity=1) and per-100g (servingQuantity=100) foods correctly. Zero-division guard: `qty / (sq > 0 ? sq : 1)`
- **Auto-calc calories**: `ManualFoodForm` auto-computes calories from protein/carbs/fat (4-4-9 rule) on every macro field change; a `_caloriesManuallyEdited` flag prevents overwriting user-entered values until all three macro fields are cleared
- **Recipe macros**: computed dynamically from ingredients (not stored as snapshots); scale = portion / servingSize
- **Logging a recipe**: creates single `food_entry` with summed macros × scale, sets `recipe_id` FK
- **CSV export**: sync (`compute`), writes to temp dir, shares via `share_plus`
- **Log tab entry delete**: delete button (trash icon) per entry in today's list; shows confirmation dialog; `ref.invalidate(todaysFoodProvider)` updates the list on success
- **Search delegate recent foods**: `FoodSearchDelegate` shows `_RecentFoodsSection` (ConsumerWidget watching `recentFoodsProvider`) when query is empty; tapping selects the food as if it were a search result
- **Onboarding complete** (`_onOnboardingComplete` in `app.dart`): invalidates `bodyweightProvider`, `todaysFoodProvider`, and `userGoalsProvider` so providers re-fetch with the newly saved data
- **Unit preference helpers** (`UnitPreferences` in `unit_preferences_provider.dart`): `displayWeight(double kg)` converts kg→lb, `kgWeight(double display)` converts lb→kg; use `unitPreferencesProvider` instead of reading `useImperial` directly from the DB
- **Data reset**: `resetAll()` truncates all 6 tables in FK-safe order within a transaction; increments `resetTriggerProvider` → `App` re-checks onboarding

## Important notes

- `flutter analyze` should always pass with zero issues
- In-memory drift DBs don't enforce foreign keys; rely on explicit delete ordering or explicit cascade deletes in tests
- `databaseProvider` is intentionally un-implemented at declaration site (throws `UnimplementedError`); `main.dart` creates the real DB and overrides it
- Schema v1→v2 migration (onUpgrade) adds `serving_unit` and `serving_quantity` columns to `foods` and backfills from `serving_label` / `serving_size_grams` patterns
- `recentFoodsProvider` fetches distinct `foodId`s from `food_entries` in a Dart-side loop (drift 2.31.0 has no `groupBy` on `SimpleSelectStatement`); orders by `MAX(loggedAt)` DESC, limit 10, then fetches `Food` records from the `foods` table
- All macro calculations (save, preview, recipe totals, ingredient rows, `computeRecipeMacros()`) use `macroPerServing * (qty / servingQuantity)` with a zero-division guard. When adding new macro math, always use this pattern.
- `_selectFood()` defaults to `_servings = food.servingQuantity` (not 1). This is correct with the formula fix — for per-100g foods, `_servings=100` means `macro * (100/100) = macro`, giving the right display for 1 serving.
