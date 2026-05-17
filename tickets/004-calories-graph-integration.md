# Ticket 4: Integrate Calories Graph into Dashboard

**Issue:** #2 — Add historical calories consumed graph below bodyweight graph  
**Status:** Pending  
**Priority:** Medium  
**Estimated effort:** 45 minutes  
**Dependencies:** Ticket 2, Ticket 3

---

## Context

With the `CaloriesSparkline` widget (Ticket 2) and data provider (Ticket 3) complete, this ticket integrates the calories graph into the dashboard below the bodyweight graph.

**User impact:** Users can now see calorie trends alongside weight trends for better insight into their progress.

---

## Current State

**Dashboard layout:** `lib/features/dashboard/dashboard_screen.dart`

Current structure (simplified):
```
DashboardScreen
├── Header ("Today, January 15")
├── MacroRing (large, calories)
├── MacroRing (protein, fat, carbs)
├── RateCard (loss/gain/maintenance)
├── MaintenanceCard
├── BodyweightSparkline ← Add calories graph below here
└── (end of scrollable area)
```

---

## Requirements

### Functional
- [ ] `CaloriesSparkline` widget added below `BodyweightSparkline`
- [ ] Dashboard fetches calorie data via `caloriesByDateProvider`
- [ ] Both graphs use same 30-day default window initially

### Visual
- [ ] Both graphs have consistent spacing (16px vertical between)
- [ ] Both graphs have same card styling and margins
- [ ] Section labels match style ("Bodyweight" / "Calories")
- [ ] No layout overflow on small screens (tested at 320px width)

### Loading states
- [ ] Handle 4 loading states gracefully:
  1. Both graphs loading
  2. Calories loaded, bodyweight loading
  3. Bodyweight loaded, calories loading
  4. Both loaded
- [ ] Show loading indicator for each graph independently

### Error states
- [ ] Handle errors for each graph independently
- [ ] Show error message without crashing entire dashboard

---

## Implementation Plan

1. Import `CaloriesSparkline` and `caloriesByDateProvider` in `dashboard_screen.dart`
2. Watch `caloriesByDateProvider` alongside existing providers
3. Add calories graph below bodyweight graph in `Column`
4. Handle async states (loading/error/data) for both graphs
5. Add section label "Calories" matching "Bodyweight" style

**Code structure:**
```dart
final caloriesAsync = ref.watch(caloriesByDateProvider(null)); // null = default 30 days

// In build method:
Column(
  children: [
    // ... existing widgets
    const Padding(
      padding: EdgeInsets.only(left: 16, bottom: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text('Calories', style: TextStyle(...)),
      ),
    ),
    caloriesAsync.when(
      loading: () => const CircularProgressIndicator(),
      error: (e, _) => Text('Failed to load'),
      data: (calories) => CaloriesSparkline(entries: calories),
    ),
  ],
)
```

---

## Testing

### Manual testing
1. Dashboard with no food data → calories shows "Log your first food"
2. Dashboard with food data → calories graph renders
3. Dashboard while data loads → both graphs show loading states independently
4. Dashboard at 320px width → no overflow, both graphs visible
5. Scroll dashboard → both graphs scroll smoothly

### Widget tests
Extend `test/features/dashboard/dashboard_screen_test.dart`:
```dart
testWidgets('calories graph renders below bodyweight', (tester) async {
  final calories = [
    (date: '2026-01-01', calories: 2000.0),
    (date: '2026-01-02', calories: 2200.0),
  ];
  final weights = [/* ... */];

  await pumpDashboard(tester, buildDashboard(
    [], targets,
    weights: weights,
    calories: calories, // New parameter
    goals: goals,
  ));

  expect(find.text('Bodyweight'), findsOneWidget);
  expect(find.text('Calories'), findsOneWidget);
  expect(find.byType(BodyweightSparkline), findsOneWidget);
  expect(find.byType(CaloriesSparkline), findsOneWidget);
});
```

---

## Files to Modify

| File | Changes |
|------|---------|
| `lib/features/dashboard/dashboard_screen.dart` | Add calories graph widget, watch provider, handle states (~40 lines) |

---

## Definition of Done

- [ ] Calories graph appears below bodyweight graph
- [ ] Both graphs load independently
- [ ] Section labels match style
- [ ] No layout overflow at 320px width
- [ ] `flutter analyze` passes with zero issues
- [ ] Manual testing completed
- [ ] Widget tests updated (optional)

---

## References

- `lib/features/dashboard/dashboard_screen.dart:136-146` — BodyweightSparkline integration (reference)
- Ticket 2 — `CaloriesSparkline` widget
- Ticket 3 — `caloriesByDateProvider`
