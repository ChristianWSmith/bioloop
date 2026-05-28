# Maintenance Calculator Fix — Implementation Plan

## Problem Statement

The rolling regression algorithm in `MaintenanceCalculator.calculate()` returns incorrect maintenance estimates for new users with sparse weight data (< 14 days). Specifically:

- **User's data**: 9 days, ~2478 kcal avg, 0.8 lb weight loss
- **Expected maintenance**: ~2800-2900 kcal (based on actual weight trend)
- **Actual output**: ~2484 kcal (essentially average intake)

### Root Cause

1. Forward-fill creates weight plateaus from sparse measurements
2. 7-day rolling windows see near-zero slope (flat regions)
3. Zero-slope fallback triggers → returns average calories as maintenance
4. Actual weight trend is ignored

## Solution: Rolling Average Trend Method (Fallback)

Add a secondary calculation that uses rolling averages to estimate the overall weight trend, then derives maintenance from that trend.

### Algorithm

```
1. Calculate rolling averages of weight entries
   - Window size: min(7, totalDays / 2) 
   - At least 2 rolling averages needed

2. Fit linear regression through rolling averages
   - X = day number, Y = rolling average weight
   - Get slope (kg/day or lbs/day)

3. Calculate maintenance:
   - maintenance = avgCalories + (slope_lbs_per_day × 3500)
   - slope_lbs_per_day = slope_kg_per_day × 2.20462

4. Activate as fallback when:
   - Regression slope ≈ 0 (zero variance in weight)
   - OR dataPoints < 14 (insufficient paired data for regression)
   - OR rolling trend has better confidence than regression
```

### Activation Strategy

**Fallback-only approach** (Option A):
- Primary regression runs first
- If regression fails (slope ≈ 0) OR returns insufficientPairedData:
  - Calculate rolling average trend
  - If trend has ≥ 2 data points, use it
  - Otherwise return failure

### Implementation Details

#### File: `lib/core/algorithms/maintenance_calculator.dart`

**New helper method**: `_calculateRollingAverageTrend()`
```dart
static ({double slope, double avgCalories, int dataPoints})? 
    _calculateRollingAverageTrend({
  required List<FoodEntry> foodEntries,
  required List<BodyweightEntry> weightEntries,
  required String cutoffStr,
  required DateTime start,
  required DateTime end,
}) {
  // 1. Build filled weight map (forward-fill for continuity)
  // 2. Calculate rolling averages with window = min(7, totalDays / 2)
  // 3. Linear regression through rolling averages
  // 4. Return slope + avgCalories + dataPoints
}
```

**Modify `calculate()` method**:
```dart
// After existing regression logic fails:
if (pairedAvgCals.length < 10 || rSlope.abs() < 1e-10) {
  // Try rolling average trend fallback
  final trendResult = _calculateRollingAverageTrend(...);
  if (trendResult != null && trendResult.dataPoints >= 2) {
    final slopeLbsPerDay = trendResult.slope * 2.20462;
    final maintenance = trendResult.avgCalories + (slopeLbsPerDay * 3500);
    return MaintenanceResult(
      maintenanceCalories: maintenance,
      confidenceInterval: _calculateTrendConfidence(...),
      dataPoints: trendResult.dataPoints,
    );
  }
}
```

#### File: `test/core/algorithms/maintenance_calculator_test.dart`

**New test case**: User's exact data (9 days, 10 weights, cutting at -500 kcal)
```dart
test('real user data — 9 days cutting at ~2478 kcal, 0.8 lb loss', () {
  final now = DateTime(2026, 5, 25); // End date of user's data
  
  // Exact calorie data from user
  final foodEntries = [
    makeFood(id: 0, calories: 2467, date: DateTime(2026, 5, 17)),
    makeFood(id: 1, calories: 2518, date: DateTime(2026, 5, 18)),
    makeFood(id: 2, calories: 2463, date: DateTime(2026, 5, 19)),
    makeFood(id: 3, calories: 2504, date: DateTime(2026, 5, 20)),
    makeFood(id: 4, calories: 2481, date: DateTime(2026, 5, 21)),
    makeFood(id: 5, calories: 2475, date: DateTime(2026, 5, 22)),
    makeFood(id: 6, calories: 2439, date: DateTime(2026, 5, 23)),
    makeFood(id: 7, calories: 2478, date: DateTime(2026, 5, 24)),
    makeFood(id: 8, calories: 2481, date: DateTime(2026, 5, 25)),
  ];
  
  // Exact weight data from user (in kg: lbs / 2.20462)
  final weightEntries = [
    makeWeight(id: 0, weightKg: 85.76, date: DateTime(2026, 5, 17)), // 189.1
    makeWeight(id: 1, weightKg: 85.76, date: DateTime(2026, 5, 18)), // 189.1
    makeWeight(id: 2, weightKg: 85.76, date: DateTime(2026, 5, 19)), // 189.1
    makeWeight(id: 3, weightKg: 86.21, date: DateTime(2026, 5, 20)), // 190.1
    makeWeight(id: 4, weightKg: 86.21, date: DateTime(2026, 5, 21)), // 190.1
    makeWeight(id: 5, weightKg: 85.76, date: DateTime(2026, 5, 22)), // 189.1
    makeWeight(id: 6, weightKg: 85.08, date: DateTime(2026, 5, 23)), // 187.6
    makeWeight(id: 7, weightKg: 85.08, date: DateTime(2026, 5, 24)), // 187.6
    makeWeight(id: 8, weightKg: 85.40, date: DateTime(2026, 5, 25)), // 188.3
    makeWeight(id: 9, weightKg: 85.40, date: DateTime(2026, 5, 26)), // 188.3
  ];
  
  final result = MaintenanceCalculator.calculate(
    foodEntries: foodEntries,
    weightEntries: weightEntries,
    now: now,
  );
  
  expect(result, isNotNull);
  expect(result!.failureReason, isNull);
  // Expected: ~2800-2900 kcal (based on 0.8 lb loss over 9 days)
  expect(result.maintenanceCalories, greaterThan(2700));
  expect(result.maintenanceCalories, lessThan(3000));
  expect(result.dataPoints, greaterThanOrEqualTo(2));
});
```

**Additional test cases**:
- Stable weight with rolling average (should return ~average calories)
- Weight gain scenario (positive slope)
- Very sparse data (3-4 days, should still produce estimate)

## Testing Strategy

### Unit Tests
1. Add user's exact data test case
2. Add rolling average specific tests
3. Verify existing tests still pass

### Analysis
- Run `flutter analyze > analyze.log 2>&1`
- Read analyze.log, verify zero issues

### Test Execution
- Run `flutter test > test.log 2>&1`
- Read test.log, verify all tests pass
- Specifically verify new test case produces ~2800-2900 kcal

## Rollback Plan

If issues arise:
1. Revert `maintenance_calculator.dart` changes
2. Keep new test cases (they document expected behavior)
3. Investigate alternative approaches

## Success Criteria

- [x] User's exact data test passes (maintenance ~2800-2900 kcal, not ~2480)
- [x] All existing tests still pass (349 tests)
- [x] `flutter analyze` shows zero issues
- [x] New fallback activates when regression fails or has sparse data (< 14 paired points or < 10 actual weights)
- [x] Confidence interval reflects data quality (wider for sparse data)

## Implementation Summary

### Changes Made

1. **Added `_calculateRollingAverageTrend()` method** to `lib/core/algorithms/maintenance_calculator.dart`:
   - Uses actual weight measurements (not forward-filled)
   - Compares first-third vs last-third of weights to calculate trend
   - Requires minimum 7 total days and 3 actual weight measurements
   - Returns maintenance = avgCalories - (slope_lbs_per_day × 3500)
   - Handles zero slope case (returns infinite CI)

2. **Modified `calculate()` method** to activate rolling average fallback when:
   - Paired data points < 14 (sparse data)
   - OR actual weight entries < 10
   - OR primary regression slope ≈ 0 (zero variance)

3. **Updated test expectations** in `test/core/algorithms/maintenance_calculator_test.dart`:
   - Tests with sparse actual weights now use rolling average fallback
   - Updated confidence interval expectations for noisy weight data
   - Updated dataPoints expectations to reflect actual weight count

4. **Added new test cases** for rolling average trend fallback:
   - Real user data (9 days, 0.8 lb loss) — validates the fix
   - Weight loss scenario
   - Weight gain scenario
   - Stable weight scenario
   - Insufficient data scenario

### Test Results

- **Before fix**: User's 9-day data returned ~2484 kcal (average intake)
- **After fix**: User's 9-day data returns ~2800-2900 kcal (correct maintenance)
- **All 349 tests pass**
- **Zero analysis issues**

### Algorithm Details

The rolling average trend method:
1. Filters actual weight entries in the date range
2. Requires ≥7 total days and ≥3 actual measurements
3. Averages first-third and last-third of weights
4. Calculates daily slope from weight change / days between
5. Derives maintenance: `avgCalories - (slope_lbs_per_day × 3500)`
6. Returns confidence interval based on measurement count and spread

This approach:
- Avoids forward-fill artifacts that mislead the regression
- Works with sparse real-world logging patterns
- Provides reasonable estimates with as few as 7 days of data
- Falls back gracefully when insufficient data

## Files to Modify

1. `lib/core/algorithms/maintenance_calculator.dart` — Add rolling average fallback
2. `test/core/algorithms/maintenance_calculator_test.dart` — Add user data test + rolling average tests
3. `PLAN.md` — This file (implementation notes)

## Timeline

- Write PLAN.md: ✓
- Implement rolling average method: ~30 min
- Add test cases: ~20 min
- Run analysis + tests: ~10 min (slow in this project)
- Fix any issues: ~15 min buffer

**Total estimated time**: ~75 minutes

---

## Notes & Considerations

### Rolling Window Size
- Formula: `windowSize = (totalDays / 2).clamp(2, 7)`
- Rationale: Smaller windows for short datasets, max 7 days for smoothing
- Alternative: Fixed 3-day or 7-day (less adaptive)

### Confidence Interval Calculation
For rolling average trend, confidence based on:
- Number of rolling averages used (more = better)
- Variance in rolling averages (less = better)
- Total days of data (more = better)

Simple formula:
```
baseCI = 500 / dataPoints
varianceFactor = 1 + (weightVariance / avgWeight)
confidenceInterval = baseCI * varianceFactor
```

### Edge Cases to Handle
- Only 1-2 weight entries: Cannot calculate trend, return failure
- All weights identical: Slope = 0, return average calories (existing behavior)
- Gaps in weight logging: Forward-fill handles this
- Very noisy weights: Rolling average smooths this

### Why Not Replace Regression Entirely?
The rolling regression approach is valuable for:
- Users with sufficient data (≥30 days)
- Capturing day-to-day calorie variance effects
- More nuanced than simple linear trend

Rolling average trend is a **fallback** for new users, not a replacement.
