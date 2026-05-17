# Ticket 6: Wire Time Range to Both Graphs

**Issue:** #3 — Time range toggle (1 month / 6 months / all time) for both graphs  
**Status:** Pending  
**Priority:** Medium  
**Estimated effort:** 1.5 hours  
**Dependencies:** Ticket 5

---

## Context

With the time range toggle UI in place (Ticket 5), this ticket connects the toggle to both graphs so they filter their data based on the selected range. Both graphs must always display identical time windows.

**User impact:** Users see consistent time ranges across both graphs for accurate comparison.

---

## Current State

**BodyweightSparkline:** Filters to 30 days in-widget (line 30-35 of `bodyweight_sparkline.dart`)

**CaloriesSparkline:** Will filter to 30 days by default (from Ticket 2)

**Toggle:** Created in Ticket 5 but not connected to graphs

---

## Requirements

### Functional
- [ ] `BodyweightSparkline` accepts `TimeRange` parameter
- [ ] `CaloriesSparkline` accepts `TimeRange` parameter
- [ ] Both graphs filter data based on selected range
- [ ] Both graphs always display identical time windows

### Smart Range Adjustment
- [ ] If data range < selected range, show only data range
  - Example: "All time" selected but only 14 days of data → show 14 days
- [ ] Both graphs use the same effective start date
  - `effectiveStart = max(calculatedStart, earliestDataPoint)`

### Time Range Calculations
- [ ] `oneMonth` = 30 days
- [ ] `sixMonths` = 180 days
- [ ] `allTime` = no artificial limit (use all available data)

### Visual
- [ ] X-axis labels adjust based on range (more spread out for longer ranges)
- [ ] Both graphs remain visually aligned (same width, same date labels)

---

## Implementation Plan

### Step 1: Add date calculation helper
```dart
DateTime _calculateStartDate(TimeRange range, DateTime now) {
  return switch (range) {
    TimeRange.oneMonth => now.subtract(const Duration(days: 30)),
    TimeRange.sixMonths => now.subtract(const Duration(days: 180)),
    TimeRange.allTime => DateTime(2000, 1, 1), // Effectively all time
  };
}
```

### Step 2: Update BodyweightSparkline
```dart
class BodyweightSparkline extends ConsumerWidget {
  final List<BodyweightEntry> entries;
  final TimeRange timeRange; // New parameter

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timeRange = ref.watch(dashboardTimeRangeProvider);
    final calculatedStart = _calculateStartDate(timeRange, DateTime.now());
    
    // Find earliest data point
    final earliestData = entries.isNotEmpty 
        ? DateTime.parse(entries.last.loggedAt) 
        : null;
    
    // Smart adjustment
    final effectiveStart = earliestData != null && earliestData.isAfter(calculatedStart)
        ? earliestData
        : calculatedStart;
    
    // Filter entries
    final filtered = entries.where((e) {
      final date = DateTime.parse(e.loggedAt);
      return !date.isBefore(effectiveStart);
    }).toList();
    
    // ... rest of build
  }
}
```

### Step 3: Update CaloriesSparkline
- Same pattern as BodyweightSparkline

### Step 4: Update provider (if needed)
- Modify `caloriesByDateProvider` to accept date range parameter
- Or filter in-widget after fetching all data

---

## Testing

### Manual testing
1. Select "1M" → both graphs show 30 days
2. Select "6M" → both graphs show 180 days (or all data if < 180 days)
3. Select "All" → both graphs show all available data
4. With 14 days of data, select "All" → both graphs show 14 days (smart adjustment)
5. Verify X-axis labels match between both graphs
6. Scroll horizontally on long ranges → smooth performance

### Widget tests
Extend `test/features/dashboard/dashboard_screen_test.dart`:
```dart
testWidgets('both graphs update when toggle changes', (tester) async {
  // Setup with 200 days of data
  await pumpDashboard(tester, buildDashboard([], targets, goals: goals));
  
  // Initially 1M
  expect(find.byType(BodyweightSparkline), findsOneWidget);
  expect(find.byType(CaloriesSparkline), findsOneWidget);
  
  // Switch to 6M
  await tester.tap(find.text('6M'));
  await tester.pumpAndSettle();
  
  // Verify both graphs rebuild with new range
});

testWidgets('smart range adjustment works', (tester) async {
  // Setup with only 10 days of data
  await pumpDashboard(tester, buildDashboard(
    [], targets,
    weights: tenDaysOfWeights,
    calories: tenDaysOfCalories,
    goals: goals,
  ));
  
  // Select "All"
  await tester.tap(find.text('All'));
  await tester.pumpAndSettle();
  
  // Verify graphs show 10 days, not infinite range
});
```

---

## Files to Modify

| File | Changes |
|------|---------|
| `lib/features/dashboard/widgets/bodyweight_sparkline.dart` | Accept `TimeRange` parameter, filter data (~30 lines) |
| `lib/features/dashboard/widgets/calories_sparkline.dart` | Accept `TimeRange` parameter, filter data (~30 lines) |
| `lib/providers/calories_provider.dart` | Optional: support date range parameter |

---

## Definition of Done

- [ ] Both graphs accept and respect `TimeRange` parameter
- [ ] Smart range adjustment works (data range < selected range)
- [ ] Both graphs display identical time windows
- [ ] X-axis labels align between graphs
- [ ] "All time" shows all data without artificial cap
- [ ] `flutter analyze` passes with zero issues
- [ ] Manual testing completed

---

## References

- `lib/features/dashboard/widgets/bodyweight_sparkline.dart:30-35` — current 30-day filtering
- Ticket 5 — `TimeRange` enum and toggle UI
- DISCOVERY.md — smart range adjustment requirement
