# PLAN2.md — Three Improvements Implementation Plan

## Overview

This document outlines three improvements to the bioloop app:
1. Fix recipe long-press delete functionality
2. Simplify food search sorting + add fuzzy brand search
3. Update maintenance calculator lookback (30-day min, 90-day max) + fix dashboard UI

---

## Issue 1: Recipe Long-Press Delete Not Working

### Problem
- User reports: tooltip appears but delete dialog doesn't open on long-press
- Current implementation wraps `Card` in `Tooltip` + `GestureDetector`
- Tooltip may be interfering with gesture detection

### Solution
**File**: `lib/features/recipes/recipe_list_screen.dart`

**Changes**:
1. Remove `Tooltip` wrapper entirely (user confirmed "we don't need any tooltip")
2. Keep `GestureDetector` with `onLongPress`
3. Ensure `onLongPress` directly calls `widget.onDelete()` which opens confirmation dialog
4. Keep haptic feedback and visual scale animation

**Code** (in `_RecipeCardState.build()`):
```dart
@override
Widget build(BuildContext context) {
  return GestureDetector(
    onLongPress: () async {
      setState(() => _isLongPressing = true);
      await HapticFeedback.mediumImpact();
      if (mounted) {
        setState(() => _isLongPressing = false);
        widget.onDelete(); // Opens confirmation dialog
      }
    },
    child: AnimatedScale(
      scale: _isLongPressing ? 0.95 : 1.0,
      duration: const Duration(milliseconds: 150),
      child: Card(
        // ... card content
      ),
    ),
  );
}
```

### Tests
**File**: `test/features/recipes/recipes_test.dart`

**Add test**:
```dart
testWidgets('Recipe list long-press opens delete confirmation dialog', (tester) async {
  // Setup: insert recipe via DB
  // Build RecipeListScreen in ProviderScope
  // Long-press the recipe card
  // Verify: AlertDialog appears with "Delete recipe?" title
  // Tap cancel → dialog closes, recipe still exists
  // Long-press again, tap delete → recipe removed from DB
});
```

---

## Issue 2: Simplify Food Search Sorting + Fuzzy Brand Search

### Problem
- Current: 2-tiered system (unlogged foods first, then logged foods)
- Requested: Single sort by recency, unlogged foods naturally sink to bottom
- Also: Add fuzzy search that includes brand name

### Solution A: Database Query
**File**: `lib/core/database/database.dart`

**Method**: `searchLocalByRecency({String? query, int limit = 50})`

**Changes**:
1. Remove 2-tier grouping (`unlogged` vs `logged` lists)
2. Sort ALL foods by `lastLoggedAt DESC` (nulls sink to end)
3. Unlogged foods sorted by `createdAt DESC` among themselves
4. Add fuzzy search: match on `name` OR `brand` (case-insensitive `.contains()`)

**New logic**:
```dart
Future<List<Food>> searchLocalByRecency({String? query, int limit = 50}) async {
  // Get last logged date for each food
  final allEntries = await (select(foodEntries)
        ..where((f) => f.foodId.isNotNull())
        ..orderBy([(f) => OrderingTerm(expression: f.loggedAt, mode: OrderingMode.desc)]))
      .get();

  final lastLoggedAt = <int, String>{};
  for (final entry in allEntries) {
    if (entry.foodId != null && !lastLoggedAt.containsKey(entry.foodId!)) {
      lastLoggedAt[entry.foodId!] = entry.loggedAt;
    }
  }

  final allFoods = await (select(foods).get());

  // Single sort: by lastLoggedAt DESC, nulls last
  allFoods.sort((a, b) {
    final aTime = lastLoggedAt[a.id];
    final bTime = lastLoggedAt[b.id];
    if (aTime == null && bTime == null) {
      // Both unlogged - sort by createdAt DESC
      return b.createdAt.compareTo(a.createdAt);
    }
    if (aTime == null) return 1;  // a is unlogged, sinks
    if (bTime == null) return -1; // b is unlogged, sinks
    // Both logged - sort by loggedAt DESC
    return bTime.compareTo(aTime);
  });

  // Fuzzy search: name OR brand
  if (query != null && query.trim().isNotEmpty) {
    final q = query.toLowerCase();
    return allFoods
        .where((f) => f.name.toLowerCase().contains(q) ||
                     (f.brand != null && f.brand!.toLowerCase().contains(q)))
        .take(limit)
        .toList();
  }

  return allFoods.take(limit).toList();
}
```

### Solution B: Update Tests
**File**: `test/core/database/search_local_by_recency_test.dart`

**Changes**:
1. Remove test: "unlogged foods appear before logged foods"
2. Remove test: "source does not affect ordering within unlogged group"
3. Update test: "logged foods sorted by lastLoggedAt DESC" → "all foods sorted by recency"
4. Add test: "unlogged foods sink to bottom, sorted by createdAt DESC"
5. Add test: "fuzzy search matches brand name"
6. Add test: "fuzzy search matches name OR brand"

**New tests**:
```dart
test('unlogged foods sink to bottom, sorted by createdAt DESC', () async {
  // Insert logged food A (logged yesterday)
  // Insert logged food B (logged today)
  // Insert unlogged food C (created 2 days ago)
  // Insert unlogged food D (created today)
  // Search with empty query
  // Expect order: B (logged today), A (logged yesterday), D (unlogged today), C (unlogged 2 days ago)
});

test('fuzzy search matches brand name', () async {
  // Insert food with name "Chicken Breast" brand "Tyson"
  // Search for "tyson"
  // Expect: food appears in results
});

test('fuzzy search matches name OR brand', () async {
  // Insert food A: name "Rice", brand null
  // Insert food B: name "Pasta", brand "Barilla"
  // Search for "rice"
  // Expect: food A appears
  // Search for "barilla"
  // Expect: food B appears
});
```

---

## Issue 3: Maintenance Calculator — 30-Day Min, 90-Day Max

### Problem
- Current: `lookback = 30` days, but fetches up to 365 days of food entries
- Need: Cap lookback at 90 days (3 months) to prevent outdated data from skewing results
- Also: Dashboard UI misrepresents progress (says "10+ days" but rolling average works with 7 days + 3 weights)

### Solution A: Provider Update
**File**: `lib/providers/maintenance_provider.dart`

**Changes**:
```dart
final maintenanceProvider = FutureProvider<MaintenanceResult?>((ref) async {
  ref.watch(resetTriggerProvider);
  ref.watch(dataTriggerProvider);
  final db = ref.watch(databaseProvider);
  final now = DateTime.now().subtract(const Duration(days: 1));
  
  // Use 90-day lookback (3 months max)
  // Algorithm internally uses rolling window within this period
  final lookback = 90;

  // Fetch reasonable limits (prevent loading years of data)
  final allFoodEntries = await db.getEntriesPaginated(limit: 500);
  final allWeights = await db.getWeights(limit: 200);

  return MaintenanceCalculator.calculate(
    foodEntries: allFoodEntries,
    weightEntries: allWeights,
    lookbackDays: lookback,
    now: now,
  );
});
```

### Solution B: Dashboard UI Update
**File**: `lib/features/dashboard/widgets/maintenance_card.dart`

**Problem**: UI says "Log 10+ days" but rolling average fallback works with 7 days + 3 weights.

**Changes**:
1. Update message: "Log 7+ days with 3+ weight entries to calculate maintenance"
2. Update progress bar threshold: "X/7" instead of "X/10"
3. Update progress calculation: `progress = (dataPoints / 7.0).clamp(0.0, 1.0)`

**Code** (in `_buildInsufficientData`):
```dart
switch (reason) {
  case MaintenanceFailureReason.noWeights:
    message = 'Start logging your weight to get estimates';
  case MaintenanceFailureReason.insufficientPairedData:
    message = 'Log 7+ days with 3+ weight entries to calculate maintenance';
    showProgress = true;
  case null:
    message = 'Log 7+ days with 3+ weight entries to calculate maintenance';
    showProgress = true;
}

// In progress bar section:
final dataPoints = result?.dataPoints ?? 0;
final progress = (dataPoints / 7.0).clamp(0.0, 1.0);
Text('$dataPoints/7', ...)
```

### Solution C: Documentation Update
**File**: `lib/core/algorithms/maintenance_calculator.dart`

**Update docstring** to reflect rolling average fallback requirements:
```dart
/// ## Fallback: Rolling Average Trend
/// When regression fails (insufficient paired data < 14 points or < 10 actual weights),
/// falls back to a rolling average trend method.
///
/// **Rolling average minimum requirements**:
/// - 7 total days in the lookback window
/// - 3 actual weight measurements
///
/// **Primary regression requirements**:
/// - 14 paired (calories + weight slope) data points
/// - 10 actual weight entries
```

### Tests
**File**: `test/core/algorithms/maintenance_calculator_test.dart`

**Add test**:
```dart
test('90-day lookback — uses recent data only', () async {
  // Create 120 days of food + weight data
  // First 30 days: 2000 kcal, 80kg
  // Days 31-90: 2500 kcal, 80kg (stable)
  // Days 91-120: 3000 kcal, 80kg (stable)
  // Run calculator with 90-day lookback
  // Expect: maintenance closer to 2750 (average of days 31-120) not 2500 (average of all 120)
});
```

**Update existing tests** that check "10+ days" messaging to reflect new "7+ days" threshold.

---

## Files to Modify

| File | Changes |
|------|---------|
| `lib/features/recipes/recipe_list_screen.dart` | Remove Tooltip, fix long-press gesture |
| `lib/core/database/database.dart` | Simplify `searchLocalByRecency()` sorting + add fuzzy brand search |
| `test/core/database/search_local_by_recency_test.dart` | Update tests for new sorting + add fuzzy search tests |
| `lib/providers/maintenance_provider.dart` | Change `lookback` from 30 to 90 days |
| `lib/features/dashboard/widgets/maintenance_card.dart` | Update messaging to "7+ days, 3+ weights", progress to "X/7" |
| `lib/core/algorithms/maintenance_calculator.dart` | Update docstring with new requirements |
| `test/features/recipes/recipes_test.dart` | Add long-press delete test |
| `test/core/algorithms/maintenance_calculator_test.dart` | Add 90-day lookback test |

---

## Testing Strategy

### Unit Tests
1. Recipe long-press delete interaction
2. Food search sorting (recency-only, unlogged sink)
3. Food search fuzzy matching (name + brand)
4. Maintenance 90-day lookback behavior
5. Dashboard progress bar shows correct threshold

### Analysis
- Run `flutter analyze > analyze.log 2>&1`
- Verify zero issues

### Test Execution
- Run `flutter test > test.log 2>&1`
- Verify all tests pass (expect ~350 tests)

---

## Success Criteria

- [x] Recipe long-press opens delete confirmation dialog (no tooltip)
- [x] Food search sorts by recency only (unlogged foods sink)
- [x] Food search matches brand names (fuzzy)
- [x] Maintenance uses 90-day max lookback
- [x] Dashboard shows "7+ days, 3+ weights" messaging
- [x] Dashboard progress bar shows "X/7"
- [x] All unit tests pass (350 tests)
- [x] `flutter analyze` shows zero issues

## Implementation Complete ✅

All changes implemented and verified:
- Recipe long-press delete works (Tooltip removed, GestureDetector configured)
- Food search simplified to single-tier recency sorting + fuzzy brand search
- Maintenance calculator uses 90-day lookback max
- Dashboard UI updated to show accurate progress ("7+ days, 3+ weights")
- Documentation updated with new requirements
- All 350 tests pass
- Zero analysis issues

---

## Implementation Order

1. **Recipe long-press fix** (isolated, quick win)
2. **Food search sorting + fuzzy search** (database change, requires test updates)
3. **Maintenance lookback** (provider change)
4. **Dashboard UI update** (depends on maintenance changes)
5. **Documentation update** (final polish)

---

## Rollback Plan

If issues arise:
1. Revert individual changes one at a time
2. Keep test updates (they document expected behavior)
3. Investigate and fix incrementally

**Estimated time**: ~90 minutes total
