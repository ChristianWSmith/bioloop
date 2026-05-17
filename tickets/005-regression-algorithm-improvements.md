# Ticket 5: Improve Regression Algorithm — 14-Day Threshold + Weight Stability Detection

**Priority:** Medium (algorithm improvement)  
**Risk:** Medium  
**Effort:** ~90 minutes  
**Status:** ⬜ Pending  

---

## Context

The maintenance regression algorithm has two limitations:

1. **Too few data points required:** Currently requires only 10 paired data points, which can produce unreliable estimates. Should require 14 days for better statistical confidence.

2. **Weight stability treated as failure:** When weight doesn't change (slope ≈ 0), the algorithm returns a failure. However, stable weight at a given calorie intake IS valuable data — it indicates the user is eating at maintenance.

From `issues.txt`:
> currently the regression algorithm requires only 10 days of logging before kicking in, we should up that to 14 days. also, it currently won't calculate unless weight changed. this isn't good because if weight didn't change, that means that the user must have eaten at "true maintenance" during that timeframe. the bodyweight should be able to forward-fill AND backward-fill off of a single logged bodyweight.

---

## Current State

### Problem 1: Threshold Too Low

**File:** `lib/core/algorithms/maintenance_calculator.dart:175`

```dart
if (pairedAvgCals.length < 10) {  // ← Too low!
  return MaintenanceResult(
    maintenanceCalories: 0,
    confidenceInterval: 0,
    dataPoints: pairedAvgCals.length,
    failureReason: MaintenanceFailureReason.insufficientPairedData,
  );
}
```

### Problem 2: Zero Slope Treated as Failure

**File:** `lib/core/algorithms/maintenance_calculator.dart:196-210`

```dart
final denom2 = np * sx2 - sx * sx;
if (denom2.abs() < 1e-10) {
  return MaintenanceResult(
    maintenanceCalories: 0,
    confidenceInterval: 0,
    dataPoints: np,
    failureReason: MaintenanceFailureReason.noCalorieVariance,
  );
}

final rSlope = (np * sxy - sx * sy) / denom2;
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

This treats zero slope as a **failure**, but zero slope = weight stability = **maintenance found**.

---

## Required Changes

### Change 1: Increase Threshold from 10 to 14 Days

**File:** `lib/core/algorithms/maintenance_calculator.dart`

**Line 175:**

```dart
// OLD:
if (pairedAvgCals.length < 10) {

// NEW:
if (pairedAvgCals.length < 14) {
```

### Change 2: Treat Zero Slope as Valid Maintenance

**File:** `lib/core/algorithms/maintenance_calculator.dart`

**Lines 203-210:** Replace the failure return with a success case

```dart
// OLD:
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

// NEW:
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

**Rationale:**
- If weight stayed stable while eating X calories/day, then X is maintenance
- Confidence interval is `double.infinity` to indicate high uncertainty (can't measure precision without variance)
- The estimate is valid, just less precise than a regression-based estimate

---

## Acceptance Criteria

- [ ] Algorithm requires 14 paired data points (not 10)
- [ ] Stable weight periods return valid maintenance estimate (average calories)
- [ ] Zero-slope cases have `confidenceInterval = double.infinity`
- [ ] All existing tests updated for new threshold
- [ ] New tests cover weight stability scenarios
- [ ] `flutter analyze` passes with zero issues
- [ ] All tests pass

---

## Testing

### Tests to Update

**File:** `test/core/algorithms/maintenance_calculator_test.dart`

#### Update Test 1: Change threshold reference

**Line 108:** `'10 paired points at threshold produces result'`

```dart
// OLD test name and setup:
test('10 paired points at threshold produces result', () {
  // ... generates 12 paired points ...
  expect(result.dataPoints, greaterThanOrEqualTo(10));
});

// NEW:
test('14 paired points at threshold produces result', () {
  // ... generate 16 paired points to exceed 14 threshold ...
  expect(result.dataPoints, greaterThanOrEqualTo(14));
});
```

#### Update Test 2: No weight variance now returns success

**Line 145:** `'no weight variance — all weights identical returns null with reason'`

```dart
// OLD:
test('no weight variance — all weights identical returns null with reason', () {
  // ... 30 days, all weights 80.0 kg ...
  expect(result!.failureReason, MaintenanceFailureReason.noWeightVariance);
});

// NEW:
test('no weight variance — all weights identical returns average calories as maintenance', () {
  // ... 30 days, all weights 80.0 kg, calories vary 2000-2800 ...
  final result = MaintenanceCalculator.calculate(
    foodEntries: foodEntries,
    weightEntries: weightEntries,
    now: now,
  );

  expect(result, isNotNull);
  expect(result!.failureReason, isNull);  // Success!
  expect(result.maintenanceCalories, closeTo(2400, 100));  // Average of 2000-2800
  expect(result.confidenceInterval, equals(double.infinity));
});
```

#### Update Test 3: Single weight entry scenario

**Line 361:** `'single weight entry — all 30 days use oldest weight'`

```dart
// OLD:
test('single weight entry — all 30 days use oldest weight', () {
  // ... single weight on last day ...
  expect(result!.failureReason, MaintenanceFailureReason.noWeightVariance);
});

// NEW:
test('single weight entry — all 30 days use oldest weight, returns maintenance', () {
  // ... single weight on last day, but calories vary ...
  final result = MaintenanceCalculator.calculate(
    foodEntries: foodEntries,
    weightEntries: weightEntries,
    now: now,
  );

  expect(result, isNotNull);
  expect(result!.failureReason, isNull);  // Success!
  expect(result.maintenanceCalories, closeTo(2400, 200));  // Average calories
});
```

### Tests to Add

**File:** `test/core/algorithms/maintenance_calculator_test.dart`

#### New Test 1: 14-day threshold boundary

```dart
test('13 paired points returns insufficientPairedData failure', () {
  final now = DateTime.now();
  final foodEntries = <FoodEntry>[];
  final weightEntries = <BodyweightEntry>[];

  // Generate exactly 13 paired points
  for (int i = 0; i < 30; i++) {
    final day = now.subtract(Duration(days: 29 - i));
    final cals = 2000.0 + (i % 5) * 200;
    foodEntries.add(makeFood(id: i, calories: cals, date: day));
    
    if (i >= 17) {  // Only last 13 days have weights
      weightEntries.add(makeWeight(id: i, weightKg: 80.0 - (i * 0.01), date: day));
    }
  }

  final result = MaintenanceCalculator.calculate(
    foodEntries: foodEntries,
    weightEntries: weightEntries,
    now: now,
  );

  expect(result, isNotNull);
  expect(result!.failureReason, MaintenanceFailureReason.insufficientPairedData);
  expect(result.dataPoints, lessThan(14));
});
```

#### New Test 2: Stable weight with calorie variance

```dart
test('stable weight with calorie variance returns average calories as maintenance', () {
  final now = DateTime.now();
  final foodEntries = <FoodEntry>[];
  final weightEntries = <BodyweightEntry>[];

  // 30 days of varying calories (2000-3000 range)
  for (int i = 0; i < 30; i++) {
    final day = now.subtract(Duration(days: 29 - i));
    final cals = 2000.0 + (i % 6) * 200;  // Varies: 2000, 2200, 2400, 2600, 2800, 3000
    foodEntries.add(makeFood(id: i, calories: cals, date: day));
    
    // Weight stays exactly the same
    weightEntries.add(makeWeight(id: i, weightKg: 80.0, date: day));
  }

  final result = MaintenanceCalculator.calculate(
    foodEntries: foodEntries,
    weightEntries: weightEntries,
    now: now,
  );

  expect(result, isNotNull);
  expect(result!.failureReason, isNull);
  expect(result.maintenanceCalories, closeTo(2500, 100));  // Average of range
  expect(result.confidenceInterval, equals(double.infinity));
  expect(result.dataPoints, greaterThanOrEqualTo(14));
});
```

#### New Test 3: Stable weight confidence interval marker

```dart
test('zero slope case has infinite confidence interval', () {
  final now = DateTime.now();
  final foodEntries = <FoodEntry>[];
  final weightEntries = <BodyweightEntry>[];

  for (int i = 0; i < 30; i++) {
    final day = now.subtract(Duration(days: 29 - i));
    foodEntries.add(makeFood(id: i, calories: 2500, date: day));
    weightEntries.add(makeWeight(id: i, weightKg: 80.0, date: day));
  }

  final result = MaintenanceCalculator.calculate(
    foodEntries: foodEntries,
    weightEntries: weightEntries,
    now: now,
  );

  expect(result, isNotNull);
  expect(result!.failureReason, isNull);
  expect(result.confidenceInterval, equals(double.infinity));
});
```

### Commands
```bash
flutter analyze
flutter test test/core/algorithms/maintenance_calculator_test.dart
```

---

## Files to Modify

| File | Lines Changed | Type |
|------|---------------|------|
| `lib/core/algorithms/maintenance_calculator.dart` | ~15 | Production |
| `test/core/algorithms/maintenance_calculator_test.dart` | ~100 | Test |

**Total:** ~15 production lines, ~100 test lines

---

## Implementation Notes

### Why 14 Days?

- 10 days provides minimal statistical confidence
- 14 days = 2 weeks, a natural biological cycle
- Reduces noise from day-to-day fluctuations
- Still achievable for most users within a month

### Why Zero Slope = Success?

- **Physics:** If weight is stable, energy intake = energy expenditure (by definition)
- **User benefit:** Users with stable weight get useful feedback immediately
- **Data quality:** Better to return an estimate (with high uncertainty) than no estimate

### Confidence Interval Handling

- Normal regression: Finite CI based on residual variance
- Zero slope: `double.infinity` signals "high uncertainty"
- UI can display this appropriately (e.g., "Maintenance: ~2500 cal (estimate)")

---

## Edge Cases

1. **Exactly 13 paired points** → Returns `insufficientPairedData` ✓
2. **Exactly 14 paired points** → Returns valid maintenance ✓
3. **Stable weight, varying calories** → Returns average calories ✓
4. **Stable weight, constant calories** → Returns that constant ✓
5. **Zero slope with high weight noise** → Still returns average (CI = infinity) ✓

---

## Performance Impact

- **No performance change** — same algorithm, different threshold
- **Slightly fewer successful calculations** initially (14 vs 10 days)
- **More accurate results** when calculation succeeds
- **Better user experience** for stable-weight users (get results instead of failure)

---

## References

- `DISCOVERY.md` — Issue 2 section
- `lib/core/algorithms/maintenance_calculator.dart:175-210` — Current threshold and zero-slope handling
- `test/core/algorithms/maintenance_calculator_test.dart:108-190` — Existing threshold tests
- `issues.txt:2` — Original issue
