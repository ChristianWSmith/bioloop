# Ticket 8: Add Long-Term Pattern Tests for Regression Algorithm

**Issue:** #4 — Comprehensive unit tests for regression algorithm  
**Status:** Pending  
**Priority:** Medium  
**Estimated effort:** 2.5 hours  
**Dependencies:** Ticket 7

---

## Context

Building on Ticket 7's edge case tests, this ticket adds tests for long-term usage patterns. These tests verify algorithm stability with large datasets and ensure it handles real-world journeys like weight loss, weight gain, and metabolic adaptation.

**User impact:** Confidence that algorithm works correctly for long-term users and handles various progress patterns.

---

## Current State

**File:** `test/core/algorithms/maintenance_calculator_test.dart`

After Ticket 7: 24 tests covering edge cases and common patterns.

**Missing long-term scenarios:**
- ❌ 180+ day users
- ❌ Weight loss journeys
- ❌ Weight gain journeys
- ❌ Plateau then change
- ❌ Metabolic adaptation
- ❌ Multi-year users

---

## Requirements

### New Test Cases (9 total)

1. **"Long-term user (6+ months)"**
   - 180 days of data
   - Verify algorithm stability
   - Verify performance (<1 second calculation time)

2. **"Weight loss journey"**
   - 90 days, consistent 1-2 lb/week loss
   - Verify maintenance estimate reflects changing baseline
   - Tolerance: 10% (higher due to non-stationary data)

3. **"Weight gain journey"**
   - 90 days, consistent gain
   - Mirror of weight loss test
   - Verify symmetry in algorithm behavior

4. **"Plateau then change"**
   - 30 days stable weight, then 30 days deficit
   - Tests algorithm responsiveness to regime change
   - Verify rolling window captures recent change

5. **"Adaptive thermogenesis simulation"**
   - 180 days, maintenance shifts over time
   - Simulates metabolic adaptation
   - Verify algorithm tracks changing maintenance

6. **"High variance weight measurements"**
   - Scale noise: ±2 lb daily fluctuations
   - Tests trend smoothing effectiveness
   - Verify confidence interval reflects noise

7. **"Vacation gap"**
   - 7-14 day logging gap mid-stream
   - Tests gap handling beyond single-day gaps
   - Verify algorithm handles extended gaps gracefully

8. **"Reverse diet pattern"**
   - Gradual calorie increase over 90 days
   - Weight stable (activity increases)
   - Tests algorithm with trending calories but stable weight

9. **"Multi-year user"**
   - 2+ years of data (730+ days)
   - Performance test + algorithm stability
   - Verify no degradation with very large datasets

### Performance Requirements
- 180-day test: <500ms calculation
- 2-year test: <2 second calculation
- All tests: deterministic with fixed seeds

---

## Implementation Plan

### Helper Functions to Extend
```dart
// Extend helpers from Ticket 7 for long-term data

List<FoodEntry> generateLongTermFood({
  required int days,
  required double baseCalories,
  PatternType pattern, // enum: stable, loss, gain, reverseDiet, etc.
  DateTime endDate,
});

List<BodyweightEntry> generateLongTermWeight({
  required int days,
  required double startWeight,
  WeightPattern pattern, // enum: stable, loss, gain, plateau, etc.
  double weeklyChangeLbs,
  double noiseLevel,
  Random? rng,
});
```

### Performance Test Pattern
```dart
test('multi-year user performs well', () {
  final now = DateTime(2026, 5, 17);
  final foodEntries = generateLongTermFood(days: 730, ...);
  final weightEntries = generateLongTermWeight(days: 730, ...);

  final stopwatch = Stopwatch()..start();
  final result = MaintenanceCalculator.calculate(
    foodEntries: foodEntries,
    weightEntries: weightEntries,
    now: now,
  );
  stopwatch.stop();

  expect(result, isNotNull);
  expect(stopwatch.elapsedMilliseconds, lessThan(2000)); // <2 seconds
  // ... other assertions
});
```

---

## Testing

### Run all tests
```bash
flutter test test/core/algorithms/maintenance_calculator_test.dart > test.log 2>&1
# Read test.log to verify all 33 tests pass (18 existing + 6 from T7 + 9 new)
```

### Performance profiling
```bash
# Time individual tests
flutter test test/core/algorithms/maintenance_calculator_test.dart --name "multi-year"
# Verify completes in <2 seconds
```

### Determinism check
```bash
# Run same test 3 times, verify identical results
flutter test test/core/algorithms/maintenance_calculator_test.dart --name "weight loss journey"
# Repeat 3x, compare output
```

---

## Files to Modify

| File | Changes |
|------|---------|
| `test/core/algorithms/maintenance_calculator_test.dart` | Add 9 new tests (~400-500 lines) |

---

## Definition of Done

- [ ] All 9 new tests pass
- [ ] All 24 existing tests still pass (no regressions)
- [ ] Performance tests complete within time limits
- [ ] Tests are deterministic (fixed random seeds)
- [ ] Test names clearly describe the scenario
- [ ] Weight loss/gain tests use appropriate tolerance (10%)
- [ ] `flutter analyze` passes with zero issues
- [ ] All tests run in <30 seconds total

---

## Special Considerations

### Weight Loss/Gain Test Tolerance
Long-term weight change introduces non-stationarity, so maintenance estimates may not converge to a single "true" value. Use 10% tolerance instead of 5%:
```dart
expect(result.maintenanceCalories, closeTo(expected, expected * 0.10));
```

### Multi-Year Test Performance
If 730 days causes slowdowns:
- Profile algorithm to identify bottlenecks
- Consider optimizing rolling window calculation
- Document performance characteristics in algorithm comments

### Metabolic Adaptation Modeling
True metabolic adaptation is complex. For testing purposes, simulate as:
- Days 1-90: maintenance = 2500 cal
- Days 91-180: maintenance = 2300 cal (body adapted to deficit)
- Verify algorithm tracks somewhere between these values

---

## References

- Ticket 7 — helper functions and test patterns
- `test/core/algorithms/maintenance_calculator_test.dart:48-78` — reference test structure
- `lib/core/algorithms/maintenance_calculator.dart:48-225` — algorithm implementation
- DISCOVERY.md — detailed long-term test scenarios
