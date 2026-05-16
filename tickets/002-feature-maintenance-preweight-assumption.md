# Ticket #2: [FEATURE] Assume oldest weight for dates before first entry

**Priority:** 🟡 High  
**Effort:** Medium (4-6 hours)  
**Status:** Pending  
**Assignee:** Unassigned  
**Created:** May 16, 2026  
**Tags:** `feature`, `algorithm`, `maintenance`, `bodyweight`

---

## Problem Statement

Currently, the maintenance calorie regression algorithm excludes all dates before the first weight entry. This causes new users with sparse early data to get no maintenance estimate (returns `null`).

**User Impact:** New users who onboard and log only 1-6 weights get no maintenance estimate because the algorithm requires 7+ weight points in the 30-day window.

### Example Scenario

User onboards on May 16, 2026 at 190 lbs:
- **Current behavior:** Only May 16 has weight data → `recentWeights.length = 1` → returns `null` (line 77)
- **Desired behavior:** Assume 190 lbs for April 16 - May 15 → `recentWeights.length = 30` → can calculate estimate

As stated in the issue:
> "if i onboard today (may 16 2026) at 190lb, it should assume that i was 190lb on all dates prior to may 16. if i then logged 188 on may 17 and deleted the logged bodyweight from may 16, it should assume i was 188 on all dates before may 17."

---

## Current Algorithm Behavior

**File:** `lib/core/algorithms/maintenance_calculator.dart:50-78`

```dart
// Forward-fill: ensure every day has a weight entry
final dateMap = <String, double>{};
for (final w in recentWeights) {
  final date = w.loggedAt.substring(0, 10);
  dateMap[date] = w.weightKg;
}

final start = DateTime.parse(cutoffStr);
final end = today;
final filledWeights = <BodyweightEntry>[];
double? lastKnownWeight;
for (int d = 0; d <= end.difference(start).inDays; d++) {
  final date = start.add(Duration(days: d));
  final dateStr = /* formatted */;
  if (dateMap.containsKey(dateStr)) {
    lastKnownWeight = dateMap[dateStr]!;  // Update on actual weight day
  }
  if (lastKnownWeight != null) {  // ← KEY: Only adds if weight exists
    filledWeights.add(BodyweightEntry(
      id: -1,
      weightKg: lastKnownWeight,
      loggedAt: dateStr,
    ));
  }
}
```

**Current behavior by scenario:**

| Scenario | Behavior |
|----------|----------|
| Date has actual weight entry | Uses actual weight ✓ |
| Date between first and last weight (no entry) | Forward-fills with last known weight ✓ |
| **Date before first weight entry** | **Excluded entirely** ✗ |
| Date after last weight entry (up to yesterday) | Forward-fills with last known weight ✓ |

---

## Acceptance Criteria

### Functional
- [ ] Single weight entry (onboarding) → all 30 days in window use that weight
- [ ] Weight entries starting mid-window → prior dates use oldest weight
- [ ] Delete oldest weight → assumption shifts to new oldest weight
- [ ] Multiple weight entries → behavior unchanged for dates after first entry
- [ ] No weight entries → returns `null` (existing behavior)

### Algorithm Requirements
- [ ] Minimum 7 weight points check still applies (after forward-fill)
- [ ] Regression slope calculation unchanged
- [ ] Minimum 14 paired data points check still applies
- [ ] Confidence interval calculation unchanged

### Edge Cases
- [ ] User onboards with 1 weight → gets maintenance estimate (may be null if no variance)
- [ ] User has weights on day 15-30 only → days 1-14 use oldest weight
- [ ] User deletes all weights → returns `null`
- [ ] User has 2 weights, deletes oldest → all prior dates use new oldest

### Non-Functional
- [ ] Algorithm performance unchanged (< 100ms for 365 food entries + 60 weights)
- [ ] No breaking changes to existing users with 7+ weights
- [ ] Code comments document forward-fill behavior

---

## Technical Implementation

### Files to Modify

1. **`lib/core/algorithms/maintenance_calculator.dart`** (lines 57-78)
   - Initialize `lastKnownWeight` to oldest weight instead of `null`

2. **`test/core/algorithms/maintenance_calculator_test.dart`**
   - Add test: single weight entry → all 30 days use that weight
   - Add test: delete oldest weight → assumption shifts
   - Add test: mid-window start → prior dates use oldest weight

### Code Change

**Location:** `maintenance_calculator.dart:57-78`

**Current code:**
```dart
final start = DateTime.parse(cutoffStr);
final end = today;
final filledWeights = <BodyweightEntry>[];
double? lastKnownWeight;
for (int d = 0; d <= end.difference(start).inDays; d++) {
  final date = start.add(Duration(days: d));
  final dateStr =
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  if (dateMap.containsKey(dateStr)) {
    lastKnownWeight = dateMap[dateStr]!;
  }
  if (lastKnownWeight != null) {
    filledWeights.add(BodyweightEntry(
      id: -1,
      weightKg: lastKnownWeight,
      loggedAt: dateStr,
    ));
  }
}
```

**Fixed code:**
```dart
final start = DateTime.parse(cutoffStr);
final end = today;
final filledWeights = <BodyweightEntry>[];

// Find the oldest known weight (first entry in sorted list)
final oldestWeight = recentWeights.isNotEmpty ? recentWeights.first.weightKg : null;

// Initialize to oldest weight so all prior dates use this assumption
double? lastKnownWeight = oldestWeight;
for (int d = 0; d <= end.difference(start).inDays; d++) {
  final date = start.add(Duration(days: d));
  final dateStr =
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  if (dateMap.containsKey(dateStr)) {
    lastKnownWeight = dateMap[dateStr]!;  // Update on actual weight day
  }
  if (lastKnownWeight != null) {
    filledWeights.add(BodyweightEntry(
      id: -1,
      weightKg: lastKnownWeight,
      loggedAt: dateStr,
    ));
  }
}
```

### Add Documentation Comment

**Location:** Before `MaintenanceCalculator.calculate()` method (line 17)

```dart
/// Calculates maintenance calories using rolling linear regression.
///
/// ## Forward-Fill Behavior
/// - Dates with actual weight entries use the logged weight
/// - Dates between first and last weight use last-known weight (forward-fill)
/// - **Dates before first weight entry use the oldest weight** (assumes no change prior to onboarding)
/// - Dates after last weight (up to yesterday) use last-known weight
///
/// This ensures new users with sparse early data can still get maintenance estimates.
/// The algorithm assumes weight stability before the first logged weight.
///
/// ## Requirements
/// - Minimum 7 weight points in 30-day window (after forward-fill)
/// - Minimum 14 paired (calories, weight-slope) data points
/// - Non-zero regression slope
```

---

## Testing Plan

### Unit Tests (Add to `test/core/algorithms/maintenance_calculator_test.dart`)

**Test 1: Single weight entry (onboarding scenario)**
```dart
test('single weight entry — all 30 days use oldest weight', () {
  final now = DateTime.now();
  final foodEntries = <FoodEntry>[];
  final weightEntries = <BodyweightEntry>[];

  // 30 days of food at 2500 kcal
  for (int i = 0; i < 30; i++) {
    final day = now.subtract(Duration(days: 29 - i));
    foodEntries.add(makeFood(id: i, calories: 2500, date: day));
  }

  // Single weight on last day (onboarding today)
  weightEntries.add(makeWeight(id: 0, weightKg: 80.0, date: now));

  final result = MaintenanceCalculator.calculate(
    foodEntries: foodEntries,
    weightEntries: weightEntries,
    now: now,
  );

  // Should have 30 weight points (all forward-filled with 80.0)
  // But no weight variance → slope = 0 → returns null
  expect(result, isNull);  // Expected: no variance means no maintenance estimate
});
```

**Test 2: Two weights, delete oldest**
```dart
test('delete oldest weight — assumption shifts to new oldest', () {
  final now = DateTime.now();
  final foodEntries = <FoodEntry>[];
  final weightEntries = <BodyweightEntry>[];

  // 30 days of food
  for (int i = 0; i < 30; i++) {
    final day = now.subtract(Duration(days: 29 - i));
    foodEntries.add(makeFood(id: i, calories: 2500, date: day));
  }

  // Two weights: day 1 (80.0 kg) and day 2 (79.5 kg)
  final day1 = now.subtract(const Duration(days: 29));
  final day2 = now.subtract(const Duration(days: 28));
  weightEntries.add(makeWeight(id: 0, weightKg: 80.0, date: day1));
  weightEntries.add(makeWeight(id: 1, weightKg: 79.5, date: day2));

  final result1 = MaintenanceCalculator.calculate(
    foodEntries: foodEntries,
    weightEntries: weightEntries,
    now: now,
  );

  // Verify: days before day1 use 80.0 kg
  expect(result1, isNotNull);

  // Now remove day1 weight (simulate deletion)
  weightEntries.removeAt(0);

  final result2 = MaintenanceCalculator.calculate(
    foodEntries: foodEntries,
    weightEntries: weightEntries,
    now: now,
  );

  // Verify: days before day2 now use 79.5 kg (new oldest)
  expect(result2, isNotNull);
  // Note: slope will differ because assumption changed
});
```

**Test 3: Mid-window start**
```dart
test('weight entries start mid-window — prior dates use oldest weight', () {
  final now = DateTime.now();
  final foodEntries = <FoodEntry>[];
  final weightEntries = <BodyweightEntry>[];

  // 30 days of food
  for (int i = 0; i < 30; i++) {
    final day = now.subtract(Duration(days: 29 - i));
    foodEntries.add(makeFood(id: i, calories: 2500, date: day));
  }

  // Weights only on days 15-30 (user started logging mid-month)
  for (int i = 15; i < 30; i++) {
    final day = now.subtract(Duration(days: 29 - i));
    final weight = 80.0 + (i - 15) * 0.1;  // Gradual increase
    weightEntries.add(makeWeight(id: i, weightKg: weight, date: day));
  }

  final result = MaintenanceCalculator.calculate(
    foodEntries: foodEntries,
    weightEntries: weightEntries,
    now: now,
  );

  // Should have 30 weight points (days 1-14 use day 15's weight)
  expect(result, isNotNull);
  expect(result!.dataPoints, greaterThanOrEqualTo(14));
});
```

**Test 4: No weights (regression)**
```dart
test('no weight entries — returns null (existing behavior)', () {
  final now = DateTime.now();
  final foodEntries = <FoodEntry>[];
  final weightEntries = <BodyweightEntry>[];

  for (int i = 0; i < 30; i++) {
    final day = now.subtract(Duration(days: 29 - i));
    foodEntries.add(makeFood(id: i, calories: 2500, date: day));
  }

  final result = MaintenanceCalculator.calculate(
    foodEntries: foodEntries,
    weightEntries: weightEntries,
    now: now,
  );

  expect(result, isNull);  // Unchanged: no weights = no estimate
});
```

### Integration Test

**Test: Full provider flow with sparse weights**
```dart
test('maintenanceProvider with single weight — emits result', () async {
  final db = AppDatabase.createInMemory();
  addTearDown(() => db.close());

  final now = DateTime.now().subtract(const Duration(days: 1));
  
  // 30 days of food
  for (int i = 0; i < 30; i++) {
    final day = now.subtract(Duration(days: 29 - i));
    final dateStr = '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
    await db.insertEntry(FoodEntriesCompanion(
      name: Value('Food $i'),
      calories: Value(2500.0),
      proteinGrams: const Value(0),
      carbsGrams: const Value(0),
      fatGrams: const Value(0),
      servings: const Value(1),
      servingLabel: const Value('serving'),
      mealType: const Value('snack'),
      loggedAt: Value('${dateStr}T12:00:00'),
    ));
  }

  // Single weight on last day
  await db.insertWeight(BodyweightEntriesCompanion.insert(
    weightKg: 80.0,
    loggedAt: '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
  ));

  final container = ProviderContainer(
    overrides: [databaseProvider.overrideWithValue(db)],
  );
  addTearDown(() => container.dispose());

  final result = await container.read(maintenanceProvider.future);
  
  // Single weight → no variance → null (expected)
  // But forward-fill should have occurred (30 weight points)
  expect(result, isNull);  // No variance, so null is correct
});
```

---

## Manual Testing Checklist

1. **Onboarding scenario**
   - [ ] Create new user, log 30 days of food, log 1 weight today
   - [ ] Check maintenance estimate (may be null due to no variance)
   - [ ] Verify no errors in console

2. **Sparse early data**
   - [ ] Log 30 days of food
   - [ ] Log weights only on days 20-30
   - [ ] Verify maintenance estimate appears
   - [ ] Verify estimate is reasonable (not extreme values)

3. **Delete oldest weight**
   - [ ] Log weights on days 1, 2, 3, ..., 30
   - [ ] Verify maintenance estimate
   - [ ] Delete day 1 weight
   - [ ] Verify maintenance estimate updates (may change due to new assumption)

4. **Regression: existing users**
   - [ ] User with 30 days of weights → estimate unchanged
   - [ ] User with 60 days of weights → estimate unchanged
   - [ ] Performance unchanged (< 100ms calculation time)

---

## Definition of Done

- [ ] Code change implemented
- [ ] Algorithm documentation comment added
- [ ] Unit tests added and passing (4 new tests)
- [ ] Integration test added and passing
- [ ] Manual testing checklist complete
- [ ] No regressions in existing maintenance tests (`flutter test test/core/algorithms/`)
- [ ] `flutter analyze` passes with zero issues
- [ ] Performance verified (< 100ms for typical data)

---

## Dependencies

- None (algorithm change, no UI dependencies)

---

## References

- Discovery report: `DISCOVERY.md` (Issue #4 section)
- Related files:
  - `lib/core/algorithms/maintenance_calculator.dart:50-78`
  - `lib/providers/maintenance_provider.dart`
  - `test/core/algorithms/maintenance_calculator_test.dart`

---

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Existing users' estimates change | Low | Medium | Only affects users with < 7 weights (likely none) |
| False confidence in estimate | Medium | Low | Estimate still requires 14+ paired points, variance |
| Performance degradation | Low | Low | One additional list access, negligible |

---

## Notes

**Impact on New Users:**
- Users with 1-6 weights will now get maintenance estimates (previously `null`)
- Estimates may have high uncertainty (wide confidence intervals) due to low variance
- Consider adding UI indicator: "Early estimate — log more weights for accuracy"

**Future Enhancement:**
After implementation, consider adding a UI note when pre-weight assumption is used:
> "Assuming stable weight before your first logged weight on [date]"
