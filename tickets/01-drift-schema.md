# T1 — Drift schema + migrations

Set up the drift database with all 4 tables and generate DAOs.

## Tables

See PLAN.md §1 for full SQL DDL.

- `foods` — searchable reference / cache of API and manual foods
- `food_entries` — immutable daily log snapshots
- `bodyweight_entries` — weight log
- `user_goals` — singleton config row

## Files to create

- `lib/core/database/database.dart` — `AppDatabase` class extending `GeneratedDatabase`
- `lib/core/database/tables/foods.dart`
- `lib/core/database/tables/food_entries.dart`
- `lib/core/database/tables/bodyweight_entries.dart`
- `lib/core/database/tables/user_goals.dart`
- `lib/providers/database_provider.dart` — `databaseProvider` (Riverpod)
- `build.yaml` (project root) — drift build config

## Acceptance criteria

- `flutter pub get` installs drift + deps without errors
- `flutter pub run build_runner build` generates `database.g.dart` with all DAOs
- `databaseProvider` can be read and returns a ready `AppDatabase`
- Tables exist after calling `await db.migrate()`

## Dependencies

Add to `pubspec.yaml`:
- `drift`
- `sqlite3_flutter_libs`
- `path_provider`
- `sqlite3` (dev)
- `drift_dev` (dev)
- `build_runner` (dev)
