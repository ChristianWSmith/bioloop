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
- `lib/core/database/tables/user_goals.dart` — includes new columns: `sex`, `height_cm`, `age`, `goal_weight_kg`, `use_imperial`, `activity_level`, `onboarding_completed`
- `lib/providers/database_provider.dart` — `databaseProvider` (Riverpod)
- `build.yaml` (project root) — drift build config

## Acceptance criteria

- `flutter pub get` installs drift + deps without errors
- `flutter pub run build_runner build` generates `database.g.dart` with all DAOs
- `databaseProvider` can be read and returns a ready `AppDatabase`
- Tables exist after calling `await db.migrate()`

## Testing

- **Unit — in-memory DB creation**: `AppDatabase` can be constructed with `NativeDatabase.memory()`, tables are queryable
- **Unit — table existence**: `select top 1 from foods` and `food_entries` and `bodyweight_entries` and `user_goals` do not throw
- **Unit — basic CRUD each table**: insert a row, read it back, verify columns
- **Unit — `user_goals` singleton**: inserting a second row with `id=1` replaces the first (upsert behavior)
- **Unit — new columns**: `goal_weight_kg`, `use_imperial`, `activity_level` have correct defaults after table creation
- **Unit — index works**: insert 100 foods, search by partial name, verify it returns matches
- **Integration — migration**: `db.migrate()` creates all tables; calling it again is a no-op

All DB unit tests should use `NativeDatabase.memory()` to avoid filesystem dependencies.

## Human verification

- [ ] `flutter analyze` passes with zero errors
- [ ] `flutter pub run build_runner build` succeeds and `database.g.dart` is generated
- [ ] Generated DAO classes have correct table/column names matching the DDL in PLAN.md
- [ ] `user_goals` uses `id=1` as a singleton — verify upsert logic doesn't create duplicates
- [ ] `goal_weight_kg` is nullable and null by default
- [ ] `use_imperial` defaults to 0 (metric) after table creation
- [ ] `activity_level` defaults to 3 (moderate) after table creation
- [ ] `foods.barcode` is `UNIQUE` — verify the DAO handles constraint violations gracefully
- [ ] `food_entries.food_id` is nullable `INTEGER REFERENCES foods(id)` — verify FK is enforced or handled correctly (drift FK behavior)
- [ ] All four unit tests with `NativeDatabase.memory()` pass
- [ ] `databaseProvider` is a proper Riverpod provider (not a plain singleton) so it can be overridden in tests

## Dependencies

Add to `pubspec.yaml`:
- `drift`
- `sqlite3_flutter_libs`
- `path_provider`
- `sqlite3` (dev)
- `drift_dev` (dev)
- `build_runner` (dev)

## Agent instructions (app state tracking)

After completing the work in this ticket, append a row to the `## App State` table in `AGENTS.md`:

| T1 — Drift schema + migrations | ✅ Complete | YYYY-MM-DD | AI |

See `AGENTS.md` for the current state table.
