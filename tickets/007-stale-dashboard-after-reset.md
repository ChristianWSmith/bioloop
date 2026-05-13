# 007 — Fix stale dashboard data after reset

- **Phase**: 3 — Bug Fixes
- **Priority**: High

## Overview

When the user triggers "Delete Everything" in settings, `resetAll()` clears all 7 tables and increments `resetTriggerProvider`. However, the dashboard's four `FutureProvider`s (`todaysFoodProvider`, `macroTargetsProvider`, `bodyweightProvider`, `userGoalsProvider`) hold cached values and don't know about the reset. The dashboard continues to display old data until something else forces invalidation (e.g., logging a new food entry).

## Context from Discovery

- `resetAll()` (`lib/core/database/database.dart:302–312`): truncates all tables in FK-safe order within a transaction.
- `resetTriggerProvider` (`lib/providers/reset_provider.dart`): `StateProvider<int>` incremented after reset.
- `_AppState` in `app.dart` listens to `resetTriggerProvider` and re-checks onboarding — this part works correctly.
- Dashboard providers are `FutureProvider`s that cache results. None of them `ref.watch(resetTriggerProvider)`.
- `databaseProvider` is a plain `Provider<AppDatabase>` with a fixed value — never invalidates.
- The "stale data" issue: `entriesAsync.value` still has pre-reset entries, `weightsAsync.value` still has pre-reset weights, etc. The empty-state guard (`entries.isEmpty && weights.isEmpty && goals == null`) never triggers because cached values are non-empty.

## Solution Options

**Option A (recommended)**: Add `ref.watch(resetTriggerProvider)` to each of the four dashboard providers so they re-execute when the trigger increments.

**Option B**: Invalidate all relevant providers in the settings screen after `resetAll()`.

Option A is more robust because it handles any code path that calls reset, not just the settings screen.

## Files to Modify

| File | Change |
|------|--------|
| `lib/providers/food_log_provider.dart` (`todaysFoodProvider`) | Add `ref.watch(resetTriggerProvider)` so it refreshes after reset |
| `lib/providers/bodyweight_provider.dart` | Add `ref.watch(resetTriggerProvider)` |
| `lib/providers/goals_provider.dart` (`userGoalsProvider`) | Add `ref.watch(resetTriggerProvider)` |
| `lib/providers/macro_targets_provider.dart` | Add `ref.watch(resetTriggerProvider)` (or it will auto-refresh when its upstream `userGoalsProvider` refreshes — verify) |
| `lib/providers/maintenance_provider.dart` | Add `ref.watch(resetTriggerProvider)` (same, may auto-refresh via upstream) |

The trigger may need to be added only to the leaf providers. `macroTargetsProvider` depends on `userGoalsProvider` + `bodyweightProvider` + `maintenanceProvider` — if all of those refresh, `macroTargetsProvider` will also re-execute automatically.

## Acceptance Criteria

- [ ] After `resetAll()`, dashboard shows empty state (onboarding prompt) immediately
- [ ] After completing a new onboarding, dashboard shows correct (empty) data
- [ ] Dashboard does NOT flash stale data after reset
- [ ] `flutter analyze` passes with zero errors
- [ ] Existing tests pass

## Testing

- Unit/integration test: call `resetAll()`, increment trigger, verify `todaysFoodProvider` re-fetches (becomes empty)
- Widget test: mock database, simulate reset, verify dashboard shows empty state
- Test that no data races or infinite re-build loops occur (providers should re-execute once per trigger change)
