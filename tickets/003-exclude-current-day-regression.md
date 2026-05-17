# Ticket 3: Exclude Current Day from Regression Calculation

**Priority:** Medium (data quality)  
**Risk:** Low  
**Effort:** ~20 minutes  
**Status:** ⬜ Pending  

---

## Context

The regression algorithm calculates maintenance calories from the past 30 days of food and weight data. However, today's data is incomplete — users may log more food throughout the day. Including today's partial data can skew the maintenance estimate.

From `issues.txt`:
> double check that the regression algorithm doesn't include the current day. the current day necessarily won't have all food logged for it, so it would throw off the data

**Example scenario:**
- User logs breakfast and lunch (1500 cal) but not dinner yet
- Today's incomplete data is included in regression
- Algorithm underestimates maintenance by ~500-1000 cal

---

## Current State

**File:** `lib/providers/maintenance_provider.dart`

Line 10 already excludes today:
```dart
final now = DateTime.now().subtract(const Duration(days: 1));
```

This means the regression window ends at **yesterday**.

**File:** `lib/core/algorithms/maintenance_calculator.dart`

However, the calculator itself doesn't defensively exclude today. If someone calls `MaintenanceCalculator.calculate()` directly without the `now` parameter:

```dart
final today = now ?? DateTime.now();  // Line 49
// This includes today if `now` is not provided!
```

The forward-fill loop (lines 86-87) and calorie aggregation (lines 56-59) would include today's data.

---

## Required Changes

**File:** `lib/core/algorithms/maintenance_calculator.dart`

**Line 49:** Make the exclusion defensive

```dart
// OLD:
final today = now ?? DateTime.now();

// NEW:
final today = (now ?? DateTime.now()).subtract(const Duration(days: 1));
```

This ensures today is always excluded, even if the calculator is called directly without the `now` parameter.

---

## Acceptance Criteria

- [ ] Today's food entries excluded from calorie aggregation
- [ ] Today's date excluded from forward-fill loop
- [ ] Existing tests with explicit `now` parameter unaffected
- [ ] New test verifies today's food not included when called without `now`
- [ ] `flutter analyze` passes with zero issues
- [ ] All existing tests pass

---

## Testing

### Unit Test to Add

**File:** `test/core/algorithms/maintenance_calculator_test.dart`

Add a new test at the end of the `MaintenanceCalculator.calculate` group:

```dart
test('excludes today from calorie aggregation', () {
  final today = DateTime.now();
  final yesterday = today.subtract(const Duration(days: 1));
  final foodEntries = <FoodEntry>[];
  final weightEntries = <BodyweightEntry>[];

  // Add 30 days of food with consistent calories
  for (int i = 0; i < 30; i++) {
    final day = today.subtract(Duration(days: 29 - i));
    final cals = 2500.0;  // Consistent calories
    foodEntries.add(makeFood(id: i, calories: cals, date: day));
  }

  // Add today's food with VERY DIFFERENT calories (should be excluded)
  foodEntries.add(makeFood(
    id: 30,
    calories: 5000.0,  // Outlier that would skew results
    date: today,
  ));

  // Add weights for all days
  for (int i = 0; i < 31; i++) {
    final day = today.subtract(Duration(days: 30 - i));
    weightEntries.add(makeWeight(id: i, weightKg: 80.0, date: day));
  }

  // Call without `now` parameter — should default to excluding today
  final result = MaintenanceCalculator.calculate(
    foodEntries: foodEntries,
    weightEntries: weightEntries,
  );

  // Should produce valid result (not skewed by today's 5000 cal outlier)
  expect(result, isNotNull);
  expect(result!.failureReason, isNull);
  // If today was included, maintenance would be inflated
  // With today excluded, should be close to 2500
  expect(result.maintenanceCalories, closeTo(2500.0, 250));
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
| `lib/core/algorithms/maintenance_calculator.dart` | 1 | Production |
| `test/core/algorithms/maintenance_calculator_test.dart` | ~40 | Test |

**Total:** 1 production line, ~40 test lines

---

## Implementation Notes

- The `maintenanceProvider` already excludes today correctly (line 10)
- This change makes the calculator itself defensive against incorrect usage
- The change is backward-compatible — explicit `now` parameter still works as before
- No impact on existing tests (they all use explicit `now` dates)

---

## Edge Cases

1. **Called from provider** — `now` is passed as `DateTime.now() - 1 day`, works correctly ✓
2. **Called directly without `now`** — Now defaults to `DateTime.now() - 1 day`, excludes today ✓
3. **Called with explicit `now`** — Uses provided `now`, caller's responsibility ✓

---

## References

- `DISCOVERY.md` — Issue 3 section
- `lib/providers/maintenance_provider.dart:8-12` — Provider implementation
- `lib/core/algorithms/maintenance_calculator.dart:49-50` — Calculator today calculation
- `issues.txt:3` — Original issue
