# T4: Fix stale maintenance estimate on dashboard

## Context & Discovery

The dashboard shows a maintenance calories estimate with a progress indicator (e.g., "0/14 days"). After logging bodyweight and/or food, the estimate remains stale — it doesn't update to reflect the new data.

**Root cause** (from DISCOVERY.md §4): Two independent breaks in the Riverpod refresh chain.

### Break 1: `maintenanceProvider` has no reactive dependencies

```dart
// maintenance_provider.dart:7-22
final maintenanceProvider = FutureProvider<MaintenanceResult?>((ref) async {
  ref.watch(resetTriggerProvider);    // ONLY trigger — incremented on FULL RESET ONLY
  final db = ref.watch(databaseProvider);
  ...
});
```

`resetTriggerProvider` is a `StateProvider<int>` incremented **only** during full data reset (`settings_screen.dart:56`). No `ref.invalidate(maintenanceProvider)` exists anywhere in the codebase.

The provider should also watch `bodyweightProvider` and `todaysFoodProvider` so it recomputes whenever weight or food data changes.

### Break 2: `_countDataDaysProvider` is not reactive

The progress bar showing "0/14" uses a separate `FutureProvider` that calls `ref.read(databaseProvider)` — not `ref.watch()`. It computes exactly once and is never invalidated.

```dart
// maintenance_card.dart:11-32
final _countDataDaysProvider = FutureProvider<int>((ref) async {
  final db = ref.read(databaseProvider);  // ref.read() — NOT reactive!
  ...
});
```

### What "0/14" means

`MaintenanceCalculator.calculate()` requires 14+ paired data points. Each requires 3+ weights in a ±3-day window and 3+ days of calorie data. The "0/14" is the number of calendar days (in last 30) with both food and weight entries. It's a user-facing approximation of progress toward 14 valid pairs.

### Refresh trace

```
Log bodyweight → bodyweightProvider.invalidate() → bodyweightProvider recomputes
                                                   → macroTargetsProvider recomputes (watches it)
                                                   → maintenanceProvider does NOT watch it → STALE ❌

Log food → todaysFoodProvider.invalidate() → todaysFoodProvider recomputes
                                            → maintenanceProvider does NOT watch it → STALE ❌
```

## Intent

Make the maintenance estimate update automatically whenever bodyweight or food data changes. Fix both `maintenanceProvider` and `_countDataDaysProvider` to be reactive to data changes.

## Acceptance Criteria

1. Logging a bodyweight entry → maintenance estimate refreshes within one frame
2. Logging a food entry → maintenance estimate refreshes within one frame
3. Deleting a bodyweight entry → maintenance estimate refreshes
4. Deleting a food entry → maintenance estimate refreshes
5. The "X/14" progress indicator updates reactively (not stale after first render)
6. Full data reset still triggers maintenance refresh (existing behavior preserved)
7. `flutter analyze` passes with zero issues
8. All existing tests pass

## Files to modify

| File | Change |
|------|--------|
| `lib/providers/maintenance_provider.dart` | Add `ref.watch(bodyweightProvider)` and `ref.watch(todaysFoodProvider)` so the provider refetches on data changes |
| `lib/features/dashboard/widgets/maintenance_card.dart` | Fix `_countDataDaysProvider` to be reactive — either watch providers instead of `ref.read`, or derive the count from `maintenanceProvider`'s input data |

### Implementation plan

**`maintenance_provider.dart`:**

```dart
final maintenanceProvider = FutureProvider<MaintenanceResult?>((ref) async {
  ref.watch(resetTriggerProvider);
  ref.watch(bodyweightProvider);      // ADD — recompute on weight changes
  ref.watch(todaysFoodProvider);      // ADD — recompute on food changes
  final db = ref.watch(databaseProvider);
  ...
});
```

**`maintenance_card.dart`:**

Option A (simpler): Replace `_countDataDaysProvider` with a derived calculation that watches the same data providers:
```dart
final _countDataDaysProvider = FutureProvider<int>((ref) async {
  ref.watch(resetTriggerProvider);
  ref.watch(bodyweightProvider);
  ref.watch(todaysFoodProvider);
  final db = ref.watch(databaseProvider);
  ...
});
```

Option B (cleaner but slightly more work): Eliminate `_countDataDaysProvider` and compute the count inside `MaintenanceCard` from the already-available data. However, the count is different from the `MaintenanceResult?` output — it's an intermediate progress indicator that shows up even when `maintenanceProvider` returns null. So keeping it as a separate provider makes sense for UX.

## Testing

1. `flutter test > test.log 2>&1` — all pass
2. `flutter analyze > analyze.log 2>&1` — zero issues
3. Manual with fresh DB:
   - Observe "0/14" on dashboard
   - Log a bodyweight entry → observe count stays same (need both food + weight)
   - Log a food entry → observe count increments
   - After 14+ days of both data → observe maintenance estimate appears
   - Delete an entry → observe count decrements
4. Full data reset → verify maintenance estimate clears
