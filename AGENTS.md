# bioloop — AGENTS.md

Flutter macro counter that auto-adjusts daily targets based on bodyweight trends. Uses rolling regression to derive maintenance calories from logged food + weight data.

**Tech stack**: Flutter / drift / Riverpod / OpenFoodFacts API

## Commands

| Action | Command |
|--------|---------|
| Get dependencies | `flutter pub get` |
| Analyze (lint) | `flutter analyze` |
| Run tests | `flutter test` |
| Run app | `flutter run` |
| Generate drift code | `dart run build_runner build` |

## Architecture

```
lib/
  main.dart             # ProviderScope, runApp
  app.dart              # MaterialApp + onboarding gate
  theme/
    theme.dart          # AppTheme (light + dark, Material 3)
  core/
    database/
      database.dart     # AppDatabase (drift) — all DAO methods
      tables/           # 7 table definitions (drift .dart files)
    api/
      open_food_facts_client.dart
      models/food_result.dart
    algorithms/
      maintenance_calculator.dart   # rolling linear regression
      mifflin_st_jeor.dart          # BMR estimator
  providers/            # 10 Riverpod providers
  features/
    onboarding/         # first-launch setup flow
    dashboard/          # summary + progress rings + sparkline
    logging/            # food search, log, barcode, templates
    bodyweight/         # weight log + chart
    history/            # paginated entry list + CSV export
    goals/              # goal type, calorie adj, sliders
    recipes/            # create/edit/log composite dishes
    settings/           # data reset
```

## Key conventions

### Drift (database)
- 7 tables: `foods`, `food_entries`, `bodyweight_entries`, `user_goals`, `meal_templates`, `recipes`, `recipe_ingredients`
- Table definitions in `lib/core/database/tables/` (one file per table)
- All DAO methods on `AppDatabase` in `lib/core/database/database.dart`
- Use `AppDatabase.createInMemory()` for tests
- In-memory DB does NOT enforce FK constraints by default

### Riverpod
- `databaseProvider` is a simple `Provider<AppDatabase>` that must be overridden in tests
- Feature providers in `lib/providers/` — roughly one provider file per domain
- Async state handled with `AsyncValue` / `AsyncNotifierProvider` where appropriate
- `ProviderScope` wraps the app in `main.dart`; tests use `ProviderScope(overrides: [...])`

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
- **Recipe macros**: computed dynamically from ingredients (not stored as snapshots); scale = portion / servingSize
- **Logging a recipe**: creates single `food_entry` with summed macros × scale, sets `recipe_id` FK
- **Meal templates**: JSON-encoded list of food snapshots stored in `meal_templates.foods` TEXT column
- **CSV export**: sync (`compute`), writes to temp dir, shares via `share_plus`
- **Data reset**: `resetAll()` truncates all 7 tables in FK-safe order within a transaction; increments `resetTriggerProvider` → `App` re-checks onboarding

## Important notes

- `flutter analyze` should always pass with zero errors (one pre-existing info-level lint: `use_build_context_synchronously`)
- In-memory drift DBs don't enforce foreign keys; rely on explicit delete ordering or explicit cascade deletes in tests
- `databaseProvider` is intentionally un-implemented at declaration site (throws `UnimplementedError`); `main.dart` creates the real DB and overrides it
