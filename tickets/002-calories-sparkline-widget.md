# Ticket 2: Create Historical Calories Graph Widget

**Issue:** #2 — Add historical calories consumed graph below bodyweight graph  
**Status:** Pending  
**Priority:** Medium  
**Estimated effort:** 2 hours  
**Dependencies:** None

---

## Context

The dashboard currently shows a bodyweight graph but no historical calories graph. Users need to see their calorie consumption trends over time to understand their eating patterns and correlate with weight changes. This ticket creates a new `CaloriesSparkline` widget that mirrors the visual style of `BodyweightSparkline`.

**User impact:** Users cannot see calorie consumption trends, making it harder to understand their eating patterns and correlate with weight changes.

---

## Current State

**Reference:** `lib/features/dashboard/widgets/bodyweight_sparkline.dart`

The existing `BodyweightSparkline` widget:
- Uses `fl_chart` package with `LineChart`
- Shows last 30 days by default
- Renders blue line with dots (for ≤20 points)
- Optional trend line (dashed, lighter blue)
- Touch tooltips show date + weight
- Auto-scales Y-axis with 15% padding
- Empty state shows "Log your first weight" prompt

**Dashboard location:** `lib/features/dashboard/dashboard_screen.dart:136-146`

---

## Requirements

### Functional
- [ ] New `CaloriesSparkline` widget created
- [ ] Accepts `List<({String date, double calories})>` data structure
- [ ] Shows 30-day default window (configurable via parameter later)
- [ ] Renders line chart using `fl_chart`

### Visual
- [ ] Same visual style as `BodyweightSparkline`:
  - Blue line color (`Colors.blue`)
  - Dots for ≤20 data points
  - Optional trend line (dashed, `Colors.blue.withValues(alpha: 0.4)`)
  - Card with padding and margins matching bodyweight graph
- [ ] Y-axis auto-scales with 15% padding
- [ ] X-axis shows dates in "M/d" format

### Interaction
- [ ] Touch tooltips show "M/d/yy\nXXX cal" format
- [ ] Tooltips work for all data points
- [ ] Touch interaction doesn't crash with empty data

### Edge cases
- [ ] Empty state shows "Log your first food" prompt
- [ ] Single data point renders correctly (no line, just dot or bar)
- [ ] Handles very large calorie values (5000+) without overflow
- [ ] Handles zero-calorie days correctly

---

## Implementation Plan

1. Create `lib/features/dashboard/widgets/calories_sparkline.dart`
2. Mirror `BodyweightSparkline` structure:
   - Same widget signature pattern
   - Same `fl_chart` configuration
   - Same card styling
3. Replace weight-specific logic with calorie logic:
   - Y-axis label: "cal" instead of "lb"/"kg"
   - Tooltip format: "XXX cal" instead of weight
   - No unit preference conversion (calories are universal)
4. Skip trend line initially (can add in follow-up if needed)
5. Test with 0, 1, and many data points

**New file:** `lib/features/dashboard/widgets/calories_sparkline.dart` (~150 lines)

---

## Testing

### Manual testing
1. Dashboard with no food logged → shows "Log your first food"
2. Dashboard with 1 day of food → shows single point
3. Dashboard with 10 days of food → shows line with dots
4. Dashboard with 30+ days of food → shows line, no dots (too many)
5. Touch-hold on data points → tooltip appears with correct date + calories
6. Scroll dashboard → no overflow at 320px width

### Widget tests
Create `test/features/dashboard/widgets/calories_sparkline_test.dart`:
```dart
testWidgets('empty state shows prompt when no entries', (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: CaloriesSparkline(entries: []),
      ),
    ),
  );
  await tester.pumpAndSettle();
  expect(find.text('Log your first food'), findsOneWidget);
  expect(find.byType(LineChart), findsNothing);
});

testWidgets('multiple points renders line chart', (tester) async {
  final entries = [
    (date: '2026-01-01', calories: 2000.0),
    (date: '2026-01-02', calories: 2200.0),
    (date: '2026-01-03', calories: 1800.0),
  ];
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: CaloriesSparkline(entries: entries),
      ),
    ),
  );
  await tester.pumpAndSettle();
  expect(find.byType(LineChart), findsOneWidget);
});
```

---

## Files to Create

| File | Purpose |
|------|---------|
| `lib/features/dashboard/widgets/calories_sparkline.dart` | New widget (~150 lines) |

---

## Files to Reference

| File | Purpose |
|------|---------|
| `lib/features/dashboard/widgets/bodyweight_sparkline.dart` | Reference implementation |
| `lib/features/dashboard/dashboard_screen.dart` | Integration point (Ticket 4) |

---

## Definition of Done

- [ ] Widget created with same visual style as `BodyweightSparkline`
- [ ] Renders correctly with 0, 1, and many data points
- [ ] Touch tooltips work and show correct format
- [ ] No layout overflow on small screens
- [ ] `flutter analyze` passes with zero issues
- [ ] Manual testing completed
- [ ] Widget tests pass (if created)

---

## References

- `lib/features/dashboard/widgets/bodyweight_sparkline.dart` — reference implementation
- `package:fl_chart` — already in pubspec, used by bodyweight graph
- DISCOVERY.md — detailed implementation notes
