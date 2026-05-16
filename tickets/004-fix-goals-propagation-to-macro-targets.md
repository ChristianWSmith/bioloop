# Ticket 4: Fix protein/fat goal updates not propagating to macro targets

**Issue:** #6  
**Priority:** High  
**Effort:** 1 line  
**Files:** `lib/providers/macro_targets_provider.dart` (primary), optionally `lib/features/goals/goals_screen.dart`

## Context

When the user changes protein or fat goals on the Goals tab and saves, the macro targets on the Dashboard and Log tabs do not update until the app is restarted.

### Root cause

The provider dependency chain is broken:

1. `macroTargetsProvider` (`lib/providers/macro_targets_provider.dart:84`) calls `ref.watch(goalsProvider).getGoals()`
2. `goalsProvider` is a plain `Provider<GoalsService>` — it does **not** react to DB mutations
3. `GoalsScreen._save()` (`lib/features/goals/goals_screen.dart:277`) invalidates `userGoalsProvider` (a `FutureProvider<UserGoal?>`)
4. But `macroTargetsProvider` does **not** watch `userGoalsProvider` — it watches `goalsProvider`

So when `userGoalsProvider` is invalidated, `macroTargetsProvider` has no idea and continues returning stale values.

### Fix

Change `macroTargetsProvider` to watch `userGoalsProvider` instead of calling `goalsProvider.getGoals()` directly. `userGoalsProvider` reads from the same DB method (`GoalsService.getGoals()`) and is properly invalidated on save.

**Belt-and-suspenders option:** Also increment `dataTriggerProvider` in `GoalsScreen._save()`, which would additionally refresh `maintenanceProvider` (which `macroTargetsProvider` also depends on). This is not strictly required since `macroTargetsProvider` re-running from watching `userGoalsProvider` will also re-fetch `maintenanceProvider`, but it's an extra safety net.

## Acceptance criteria

- [ ] Open Dashboard → note macro targets (calories, protein, fat, carbs)
- [ ] Open Goals → change protein slider or fat percentage → Save
- [ ] Navigate back to Dashboard → macro targets reflect the new values
- [ ] Log screen macro bars also update without app restart
- [ ] Changing calorie adjustment → Save → targets update
- [ ] Changing goal type (cut/bulk/maintain) → Save → targets update
- [ ] Existing behavior: bodyweight changes still propagate to macro targets

## Testing

### Manual testing
1. Open Dashboard, screenshot macro targets
2. Goals → change protein from 1.0 to 1.5 g/lb → Save
3. Back to Dashboard → verify protein target increased proportionally
4. Goals → change fat from 25% to 35% → Save
5. Back to Dashboard → verify fat target increased, carbs decreased
6. Goals → change calorie adjustment from 0 to -300 → Save
7. Back to Dashboard → verify target calories decreased by 300

### Regression checks
- `maintenanceProvider` still watches `dataTriggerProvider` and `resetTriggerProvider` — bodyweight/food mutations still trigger maintenance refresh
- `bodyweightProvider` is still watched by `macroTargetsProvider` — weight changes still affect targets
- `macroTargetsProvider` error handling: if `userGoalsProvider` returns null, `MacroTargets.compute` handles null goals gracefully

## Implementation

```dart
// lib/providers/macro_targets_provider.dart:84
// Before:
final goals = await ref.watch(goalsProvider).getGoals();
// After:
final goals = await ref.watch(userGoalsProvider);
```
