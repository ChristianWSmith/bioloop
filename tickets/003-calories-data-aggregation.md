# Ticket 3: Add Calories-by-Date Data Aggregation

**Issue:** #2 — Add historical calories consumed graph below bodyweight graph  
**Status:** Pending  
**Priority:** Medium  
**Estimated effort:** 1.5 hours  
**Dependencies:** None

---

## Context

To display a historical calories graph, we need to aggregate food entries by date and sum calories per day. The database currently has methods to fetch entries for a single date or paginated entries, but no bulk aggregation method. This ticket adds the necessary data layer support.

**User impact:** Enables historical calorie tracking and trend analysis.

---

## Current State

**Database methods available:**
- `getEntriesForDate(DateTime date)` — returns entries for single date
- `getEntriesPaginated({int offset, int limit})` — returns raw entries, no aggregation

**Limitation:** drift 2.31.0 has no `groupBy` on `SimpleSelectStatement`, so aggregation must happen in Dart.

**Reference pattern:** `getRecentFoods()` (lines 169-201 in database.dart) uses Dart-side aggregation.

---

## Requirements

### Functional
- [ ] New method `getCaloriesByDate({DateTime? startDate, DateTime? endDate})` in `AppDatabase`
- [ ] Aggregates `food_entries` by date, sums calories per day
- [ ] Returns `List<({String date, double calories})>` sorted by date ascending
- [ ] Optional date range filtering (if null, fetches all available data)

### Provider
- [ ] New `caloriesByDateProvider` as `FutureProvider<List<({String, double})>>`
- [ ] Watches `dataTriggerProvider` for reactive refresh
- [ ] Watches `resetTriggerProvider` for reset handling
- [ ] Supports optional date range parameter

### Performance
- [ ] Fetches max 365 days by default (configurable)
- [ ] Completes in <100ms for typical datasets (<1000 entries)

---

## Implementation Plan

### Step 1: Add database method
```dart
Future<List<({String date, double calories})>> getCaloriesByDate({
  DateTime? startDate,
  DateTime? endDate,
  int limit = 365,
}) async {
  // Fetch entries
  // Aggregate by date in Dart
  // Apply date range filters
  // Sort ascending
  // Return
}
```

### Step 2: Create provider
```dart
final caloriesByDateProvider = FutureProvider.family<List<({String date, double calories})>, DateTime?>((ref, endDate) async {
  ref.watch(resetTriggerProvider);
  ref.watch(dataTriggerProvider);
  final db = ref.watch(databaseProvider);
  final start = endDate?.subtract(const Duration(days: 30));
  return await db.getCaloriesByDate(startDate: start, endDate: endDate);
});
```

**Note:** Using `FutureProvider.family` to support date range parameterization for Ticket 6.

---

## Testing

### Unit tests
Add to `test/core/database/database_test.dart` or create new file:
```dart
test('getCaloriesByDate aggregates correctly', () async {
  final db = AppDatabase.createInMemory();
  addTearDown(() => db.close());

  // Insert multiple entries for same date
  await db.insertEntry(FoodEntriesCompanion(
    name: const Value('Food 1'),
    calories: const Value(500),
    // ... other fields
    loggedAt: Value('2026-01-15T10:00:00'),
  ));
  await db.insertEntry(FoodEntriesCompanion(
    name: const Value('Food 2'),
    calories: const Value(300),
    // ... other fields
    loggedAt: Value('2026-01-15T13:00:00'),
  ));

  final result = await db.getCaloriesByDate();
  expect(result.length, 1);
  expect(result[0].date, '2026-01-15');
  expect(result[0].calories, 800);
});

test('getCaloriesByDate respects date range', () async {
  // Insert entries for multiple dates
  // Filter by range
  // Verify only matching dates returned
});
```

### Provider tests
```dart
test('caloriesByDateProvider watches triggers', () async {
  final db = AppDatabase.createInMemory();
  addTearDown(() => db.close());

  final container = ProviderContainer(
    overrides: [
      databaseProvider.overrideWithValue(db),
    ],
  );
  addTearDown(() => container.dispose());

  // Insert data
  // Verify provider returns aggregated data
  // Increment dataTriggerProvider
  // Verify provider refreshes
});
```

---

## Files to Modify

| File | Changes |
|------|---------|
| `lib/core/database/database.dart` | Add `getCaloriesByDate()` method (~40 lines) |

---

## Files to Create

| File | Purpose |
|------|---------|
| `lib/providers/calories_provider.dart` | New provider (~20 lines) |

---

## Definition of Done

- [ ] `getCaloriesByDate()` method added to `AppDatabase`
- [ ] Method aggregates correctly (sum per date)
- [ ] Method respects optional date range
- [ ] Results sorted by date ascending
- [ ] `caloriesByDateProvider` created and watches triggers
- [ ] Unit tests pass
- [ ] `flutter analyze` passes with zero issues

---

## References

- `lib/core/database/database.dart:169-201` — `getRecentFoods()` aggregation pattern
- `lib/providers/maintenance_provider.dart` — trigger watching pattern
- `lib/providers/food_log_provider.dart` — provider structure reference
