# Discovery Document — BioLoop Issues

**Date:** May 17, 2026  
**Author:** opencode  
**Scope:** Discovery work for 5 tracked issues in `issues.txt`

---

## Executive Summary

This document details the findings from discovery work on 5 issues related to calorie clamping, maintenance calculation algorithm, tab ordering, and calorie target safety. Each section includes:
- Current state analysis
- Root cause identification
- Required code changes
- Test impact assessment
- Implementation notes

---

## Issue 1: Calorie Clamping Timing (OpenFoodFacts Import)

### Problem Statement

When a user logs a food directly from OpenFoodFacts, the food appears in the log with unclamped (potentially inflated) calorie values. The calorie clamping logic (`clampCaloriesToMacros`) only runs when saving to the local database, but the preview in `QuickFoodLogSheet` shows the original API values.

**Example:** A food with 170 calories but only 10g carbs + 1g protein = 44 macro calories would show 170 cal in the preview, but save with 44 cal to the database.

### Current Flow

```
OpenFoodFacts API
    ↓
FoodResult.fromJson()  ← raw API values (unclamped)
    ↓
FoodSearchItem.fromFoodResult()  ← copies unclamped values
    ↓
QuickFoodLogSheet  ← shows unclamped preview to user
    ↓
User taps "Log entry"
    ↓
_log() method  ← clamps calories HERE (too late)
    ↓
Database  ← saved with clamped values
```

### Files Involved

| File | Line(s) | Purpose |
|------|---------|---------|
| `lib/core/api/models/food_result.dart` | 30-80 | `FoodResult.fromJson()` — parses API response |
| `lib/providers/food_search_provider.dart` | 57-69 | `FoodSearchItem.fromFoodResult()` — creates UI model |
| `lib/features/logging/widgets/quick_food_log_sheet.dart` | 149-171 | Macro preview display (shows unclamped values) |
| `lib/features/logging/widgets/quick_food_log_sheet.dart` | 59-78 | Clamping happens on save (too late) |
| `lib/core/utils/calorie_clamp.dart` | 8-16 | `clampCaloriesToMacros()` — the clamping logic |

### Required Changes

**Apply clamping at `FoodSearchItem.fromFoodResult()` conversion** — this ensures all downstream consumers (preview, logging, saving) see clamped values.

**Implementation location:** `lib/providers/food_search_provider.dart:57-69`

```dart
factory FoodSearchItem.fromFoodResult(FoodResult result) {
  final clampedCalories = clampCaloriesToMacros(
    calories: result.caloriesPerServing,
    protein: result.proteinPerServing,
    carbs: result.carbsPerServing,
    fat: result.fatPerServing,
  );
  return FoodSearchItem(
    // ... other fields
    caloriesPerServing: clampedCalories,  // ← clamped here
    // ...
  );
}
```

**Also remove duplicate clamping** from `quick_food_log_sheet.dart:59-78` since it's now redundant.

### Test Impact

**Files to update:**
- `test/providers/food_search_provider_test.dart` — add test verifying clamped values in `fromFoodResult()`
- `test/core/utils/calorie_clamp_test.dart` — already has comprehensive clamping tests

**Test cases to add:**
1. `fromFoodResult() clamps inflated calories` — API food with 170 cal but 44 macro cal → 44 cal
2. `fromFoodResult() preserves sugar alcohol foods` — API food with calories < macro cal → unchanged
3. `QuickFoodLogSheet preview shows clamped values` — widget test

### Risk Assessment

**Low risk** — clamping logic is well-tested and the change is localized to a single factory method. All existing tests should pass since they test the saved values, not the intermediate `FoodSearchItem`.

---

## Issue 2: Regression Algorithm Requirements (14 Days + Weight Stability)

### Problem Statement

The maintenance regression algorithm currently:
1. Requires only 10 paired data points (should be 14)
2. Fails when weight doesn't change (slope ≈ 0), but stable weight at a given calorie intake IS useful data — it indicates maintenance

### Current State

**File:** `lib/core/algorithms/maintenance_calculator.dart`

**Current threshold (line 175):**
```dart
if (pairedAvgCals.length < 10) {
  return MaintenanceResult(..., failureReason: insufficientPairedData);
}
```

**Current zero-slope handling (lines 196-210):**
```dart
if (rSlope.abs() < 1e-10) {
  final allWeightsIdentical = weights.toSet().length == 1;
  return MaintenanceResult(
    maintenanceCalories: 0,
    confidenceInterval: 0,
    dataPoints: np,
    failureReason: allWeightsIdentical
        ? MaintenanceFailureReason.noWeightVariance
        : MaintenanceFailureReason.noCorrelation,
  );
}
```

This treats zero slope as a failure, but **zero slope = weight stability = maintenance**.

### Required Changes

#### Change 1: Threshold from 10 → 14

**Line 175:**
```dart
if (pairedAvgCals.length < 14) {  // was 10
```

#### Change 2: Handle zero-slope as valid maintenance

When slope ≈ 0, the user's average calorie intake over that period IS their maintenance. Replace the failure return with a success case:

**Lines 196-210 replacement:**
```dart
if (rSlope.abs() < 1e-10) {
  // Zero slope = weight stability = maintenance found
  // Use average calories as maintenance estimate
  final avgCalories = sx / np;
  return MaintenanceResult(
    maintenanceCalories: avgCalories,
    confidenceInterval: double.infinity,  // High uncertainty (no slope to measure)
    dataPoints: np,
  );
}
```

**Rationale:** If weight stayed stable while eating X calories/day, then X is maintenance. The confidence interval is high because we can't measure precision without variance, but the estimate is valid.

### Forward-Fill Behavior

**Already implemented correctly** (lines 75-101):
- Dates before first weight → use oldest weight
- Dates between weights → use last-known weight
- Dates after last weight → uses last-known weight (extends to `today`)

**Issue 3 note:** The forward-fill extending to today is fine — Issue 3 only requires excluding today from calorie aggregation.

### Test Impact

**File:** `test/core/algorithms/maintenance_calculator_test.dart`

**Tests to update:**
1. `'10 paired points at threshold produces result'` (line 108) → change to 14 points
2. `'no weight variance — all weights identical returns null with reason'` (line 145) → should now return valid maintenance (average calories)
3. `'single weight entry — all 30 days use oldest weight'` (line 361) → currently expects `noWeightVariance`, should now return maintenance

**Tests to add:**
1. `'14 paired points at threshold produces result'` — new threshold test
2. `'stable weight with calorie variance returns average calories as maintenance'` — zero-slope success case
3. `'stable weight confidence interval is infinite'` — verify high uncertainty marker

### Risk Assessment

**Medium risk** — changes the algorithm's behavior for edge cases. The zero-slope case is a conceptual change (treating stability as data, not failure). Existing tests that expect failure will need updates.

---

## Issue 3: Exclude Current Day from Regression

### Problem Statement

The regression algorithm includes today's data, but today is incomplete (user may log more food). This can skew the maintenance estimate.

### Current State

**File:** `lib/providers/maintenance_provider.dart`

**Line 10:**
```dart
final now = DateTime.now().subtract(const Duration(days: 1));
```

This already subtracts 1 day, so the regression window ends **yesterday**.

**File:** `lib/core/algorithms/maintenance_calculator.dart`

**Lines 49-50:**
```dart
final today = now ?? DateTime.now();
final cutoff = today.subtract(Duration(days: lookbackDays));
```

**Lines 86-87 (forward-fill loop):**
```dart
for (int d = 0; d <= end.difference(start).inDays; d++) {
  final date = start.add(Duration(days: d));
```

The loop includes `end` (which is `today` if `now` is not provided).

**Lines 56-59 (calorie aggregation):**
```dart
for (final entry in foodEntries) {
  final date = entry.loggedAt.substring(0, 10);
  if (date.compareTo(cutoffStr) >= 0) {
    calByDate[date] = (calByDate[date] ?? 0) + entry.calories;
  }
}
```

This includes all dates from `cutoff` onward (including today if `now` is not provided).

### Analysis

**The `maintenanceProvider` already handles this correctly** by passing `now = DateTime.now() - 1 day`. This means:
- `today` in the calculator = yesterday
- Forward-fill loop ends at yesterday
- Calorie aggregation ends at yesterday

**However**, the default behavior (if someone calls `MaintenanceCalculator.calculate()` directly without the `now` parameter) would include today.

### Required Changes

**Defensive fix in `maintenance_calculator.dart`** — ensure today is always excluded even if called directly:

**Line 49:**
```dart
final today = (now ?? DateTime.now()).subtract(const Duration(days: 1));
```

This makes the exclusion explicit in the calculator itself, not just in the provider.

### Test Impact

**File:** `test/core/algorithms/maintenance_calculator_test.dart`

**Tests to verify:**
- All existing tests use `now: now` where `now` is a fixed date, so they're unaffected
- Add test: `'excludes today from calorie aggregation'` — verify that food logged on `now` is not included

### Risk Assessment

**Low risk** — the provider already does this correctly. The change makes the calculator itself defensive against incorrect usage.

---

## Issue 4: Log Screen as Default Tab

### Problem Statement

The app currently opens to the Dashboard tab (index 0). The Log tab (index 1) should be the default since it's the primary user action.

### Current State

**File:** `lib/app.dart`

**Line 99:**
```dart
int _currentIndex = 0;
```

**Lines 105-110:**
```dart
static const _screens = <Widget>[
  DashboardScreen(),      // index 0
  CombinedLogScreen(),    // index 1
  BodyweightScreen(),     // index 2
  GoalsScreen(),          // index 3
];
```

### Required Changes

**Line 99:**
```dart
int _currentIndex = 1;  // was 0
```

That's it — single line change.

### Test Impact

**Files to check:**
- `test/app_test.dart` — if exists, may have assertions about initial tab
- Widget tests that assume dashboard is visible at startup

**Search results:** No existing tests reference `_currentIndex` or assert on initial tab state.

### Risk Assessment

**Very low risk** — trivial change, no logic affected. The app hasn't been published yet, so no user muscle memory to break.

---

## Issue 5: Non-Negative Calorie Targets

### Problem Statement

If the calculated maintenance is very low and the user has a large deficit (e.g., maintenance=400, deficit=-500), the target calories would be negative. This is impossible — targets should clamp to 0.

### Current State

**File:** `lib/providers/macro_targets_provider.dart`

**Lines 38-50:**
```dart
if (regressionMaintenance != null) {
  targetCalories = regressionMaintenance + adjustment;
  maintenanceCalories = regressionMaintenance;
} else if (goals?.onboardingCompleted == 1 && ...) {
  final estimated = estimateMaintenance(...);
  targetCalories = estimated + adjustment;
  maintenanceCalories = estimated;
} else {
  targetCalories = adjustment > 1200 ? adjustment : 1200;
}
```

The pre-onboarding fallback (line 50) has a floor of 1200, but the regression and Mifflin-St Jeor paths do not.

### Required Changes

**After line 50** (after all three branches), add:
```dart
targetCalories = max(0.0, targetCalories);
```

**Import needed:** `dart:math` (already imported in this file via `MacroTargets.compute` usage).

**Location:** `lib/providers/macro_targets_provider.dart`, inside `MacroTargets.compute()` method, after the if/else block that sets `targetCalories`.

### Test Impact

**File:** `test/providers/macro_targets_provider_test.dart`

**Tests to add:**
1. `'target calories clamped to 0 when deficit exceeds maintenance'` — regression path
2. `'target calories clamped to 0 when Mifflin-St Jeor estimate is very low'` — fallback path
3. `'extreme deficit -1000 with 2000 maintenance = 1000 target (not clamped)'` — verify clamping only applies when negative

### Risk Assessment

**Low risk** — simple defensive clamp. The scenario is extremely unlikely (maintenance < 500 for a -500 deficit), but the fix ensures correctness.

---

## Summary of Changes

| Issue | Files to Modify | Lines Changed | Test Updates | Risk |
|-------|-----------------|---------------|--------------|------|
| 1. Calorie clamping timing | `food_search_provider.dart`, `quick_food_log_sheet.dart` | ~15 | Add 3 tests | Low |
| 2. Regression 14 days + stability | `maintenance_calculator.dart` | ~20 | Update 3 tests, add 3 tests | Medium |
| 3. Exclude current day | `maintenance_calculator.dart` | 1 | Add 1 test | Low |
| 4. Log screen default | `app.dart` | 1 | None | Very Low |
| 5. Non-negative targets | `macro_targets_provider.dart` | 2 | Add 3 tests | Low |

**Total estimated changes:** ~40 lines of production code, ~10 new tests, 3 test updates

---

## Implementation Order (Recommended)

1. **Issue 4** (Log screen default) — 1 line, immediate win
2. **Issue 5** (Non-negative targets) — isolated, low risk
3. **Issue 3** (Exclude current day) — defensive fix, low risk
4. **Issue 2** (14 days + stability) — algorithm change, needs careful test validation
5. **Issue 1** (Calorie clamping) — requires tracing multiple code paths, but well-tested

---

## Open Questions

None — all questions resolved during discovery:

1. ✅ Clamp at `fromFoodResult()` conversion (not at save time)
2. ✅ Zero slope = valid maintenance (use average calories)
3. ✅ Exclude today from calorie aggregation (forward-fill can extend to today)
4. ✅ No concern about breaking user muscle memory (app not published)
5. ✅ No warning needed for clamped targets (silent clamp to 0)

---

## Appendix: Related Files Reference

### Core Algorithm Files
- `lib/core/algorithms/maintenance_calculator.dart` — rolling regression
- `lib/core/algorithms/mifflin_st_jeor.dart` — BMR fallback
- `lib/core/utils/calorie_clamp.dart` — 4-4-9 clamping

### Provider Files
- `lib/providers/macro_targets_provider.dart` — target calculation
- `lib/providers/maintenance_provider.dart` — regression provider
- `lib/providers/food_search_provider.dart` — food search + save

### UI Files
- `lib/app.dart` — tab shell
- `lib/features/logging/widgets/quick_food_log_sheet.dart` — log preview
- `lib/features/logging/widgets/food_search_delegate.dart` — search UI

### Test Files
- `test/core/algorithms/maintenance_calculator_test.dart` — 14 tests
- `test/providers/macro_targets_provider_test.dart` — 13 tests
- `test/providers/food_search_provider_test.dart` — 4 tests
- `test/core/utils/calorie_clamp_test.dart` — 8 tests
