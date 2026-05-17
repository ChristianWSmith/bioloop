# Ticket 7: Add Edge Case Tests for Regression Algorithm

**Issue:** #4 — Comprehensive unit tests for regression algorithm  
**Status:** Pending  
**Priority:** High (improves confidence in core algorithm)  
**Estimated effort:** 2 hours  
**Dependencies:** None

---

## Context

The maintenance calorie regression algorithm is core to the app's value proposition. While 18 tests exist, they don't cover many real-world usage patterns. This ticket adds tests for edge cases and common user behaviors to ensure algorithm reliability.

**User impact:** Improved confidence in maintenance estimates, catching edge cases before users encounter them.

---

## Current State

**File:** `test/core/algorithms/maintenance_calculator_test.dart` (679 lines, 18 tests)

**Existing coverage:**
- ✅ Known maintenance (2500 kcal baseline)
- ✅ Insufficient data handling
- ✅ Empty input handling
- ✅ Zero variance cases
- ✅ Sparse logging (Mon+Fri only)
- ✅ Single gaps
- ✅ Forward-fill behavior

**Missing coverage:**
- ❌ Weekend binge patterns
- ❌ Weekday restriction patterns
- ❌ Inconsistent food logging (4-5 days/week)
- ❌ Barely sufficient data (exactly 10 paired days)
- ❌ Perfect adherence users
- ❌ High variance weight measurements

---

## Requirements

### New Test Cases (6 total)

1. **"Cheat high but track accurately"**
   - Pattern: 500-1000 cal over maintenance on weekends (Sat/Sun)
   - Perfect logging fidelity
   - Verify algorithm converges within 10% tolerance

2. **"Cheat low but track accurately"**
   - Pattern: 500 cal under on weekdays, compensation on weekends
   - Verify algorithm handles intentional variance

3. **"Inconsistent food logging"**
   - Pattern: Logs food 4-5 days/week randomly
   - Tests paired data calculation with missing calorie days
   - Verify doesn't fail with partial data

4. **"Barely sufficient user"**
   - Exactly 10 paired days (minimum threshold)
   - Verify succeeds with 10, fails with 9

5. **"New user with sparse data"**
   - 10-14 days total data
   - Verify confidence interval is appropriately wide
   - Verify estimate is reasonable despite limited data

6. **"Perfect adherence user"**
   - Eats exact same calories daily (e.g., 2500 every day)
   - Weight stable (no variance)
   - Should return average calories with infinite CI

### Test Structure
Each test must verify:
- [ ] Result is not null
- [ ] Correct `failureReason` (or null on success)
- [ ] `maintenanceCalories` within acceptable tolerance (5-10%)
- [ ] `confidenceInterval` reflects data quality
- [ ] `dataPoints` meets minimum threshold

---

## Implementation Plan

### Helper Functions to Add
```dart
FoodEntry makeFood({
  required double calories,
  required DateTime date,
  // ... other fields
});

BodyweightEntry makeWeight({
  required double weightKg,
  required DateTime date,
});

List<FoodEntry> generateFoodPattern({
  required double baseCalories,
  required List<double> weeklyPattern, // e.g., [0, 0, 0, 0, 0, 500, 500]
  required int days,
  required DateTime endDate,
});

List<BodyweightEntry> generateWeightData({
  required double startWeight,
  required double maintenanceCalories,
  required List<FoodEntry> foodEntries,
  double noiseLevel = 0.1,
  Random? rng,
});
```

### Test Template
```dart
test('scenario name', () {
  final now = DateTime(2026, 5, 17);
  final foodEntries = generateFoodPattern(...);
  final weightEntries = generateWeightData(...);

  final result = MaintenanceCalculator.calculate(
    foodEntries: foodEntries,
    weightEntries: weightEntries,
    now: now,
  );

  expect(result, isNotNull);
  expect(result!.failureReason, isNull);
  expect(result.maintenanceCalories, closeTo(expected, tolerance));
  expect(result.confidenceInterval, greaterThan(minimum));
  expect(result.dataPoints, greaterThanOrEqualTo(10));
});
```

---

## Testing

### Run existing tests first
```bash
flutter test > test.log 2>&1
# Read test.log to verify all 18 existing tests pass
```

### Run new tests
```bash
flutter test test/core/algorithms/maintenance_calculator_test.dart > test.log 2>&1
# Verify all 24 tests pass (18 existing + 6 new)
```

### Test determinism
- Use fixed `Random(42)` seeds for reproducibility
- Run tests multiple times to verify no flakiness

---

## Files to Modify

| File | Changes |
|------|---------|
| `test/core/algorithms/maintenance_calculator_test.dart` | Add 6 new tests (~300-400 lines) |

---

## Definition of Done

- [ ] All 6 new tests pass
- [ ] All 18 existing tests still pass (no regressions)
- [ ] Tests are deterministic (fixed random seeds)
- [ ] Test names clearly describe the scenario
- [ ] Each test verifies maintenance, CI, and dataPoints
- [ ] `flutter analyze` passes with zero issues
- [ ] Tests run in <10 seconds total

---

## References

- `test/core/algorithms/maintenance_calculator_test.dart:48-78` — existing "known maintenance" test (reference pattern)
- DISCOVERY.md — detailed test scenarios and coverage gaps
- `lib/core/algorithms/maintenance_calculator.dart` — algorithm under test
