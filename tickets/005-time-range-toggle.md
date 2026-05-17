# Ticket 5: Add Time Range Toggle UI to Dashboard

**Issue:** #3 — Time range toggle (1 month / 6 months / all time) for both graphs  
**Status:** Pending  
**Priority:** Medium  
**Estimated effort:** 1 hour  
**Dependencies:** Ticket 4

---

## Context

Users need to view different time ranges to understand their progress. Short-term users benefit from seeing all their data, while long-term users need to zoom in on recent trends. This ticket adds a UI toggle to switch between 1 month, 6 months, and all time views.

**User impact:** Users can customize their dashboard view to match their goals and data volume.

---

## Current State

**Dashboard:** Both graphs use hardcoded 30-day windows with no user control.

**Design decision (per user):** Time range is NOT persistent — defaults to 1 month on each app launch.

---

## Requirements

### Functional
- [ ] New `TimeRange` enum with values: `oneMonth`, `sixMonths`, `allTime`
- [ ] New `dashboardTimeRangeProvider` as `StateProvider<TimeRange>`
- [ ] Provider defaults to `TimeRange.oneMonth`
- [ ] Toggle UI updates provider state on selection

### Visual
- [ ] `SegmentedButton` toggle above both graphs
- [ ] Three segments with labels: "1M", "6M", "All"
- [ ] Material 3 style matching app theme
- [ ] Toggle positioned between maintenance card and bodyweight graph

### Behavior
- [ ] Not persistent (resets to 1 month on app restart)
- [ ] Toggle selection is immediate (no confirmation needed)
- [ ] Works in both light and dark themes

---

## Implementation Plan

### Step 1: Create enum and provider
```dart
// lib/providers/dashboard_time_range_provider.dart
enum TimeRange { oneMonth, sixMonths, allTime }

final dashboardTimeRangeProvider = StateProvider<TimeRange>((ref) => TimeRange.oneMonth);
```

### Step 2: Add toggle UI to dashboard
```dart
// lib/features/dashboard/dashboard_screen.dart
SegmentedButton<TimeRange>(
  segments: const [
    ButtonSegment(value: TimeRange.oneMonth, label: Text('1M')),
    ButtonSegment(value: TimeRange.sixMonths, label: Text('6M')),
    ButtonSegment(value: TimeRange.allTime, label: Text('All')),
  ],
  selected: {ref.watch(dashboardTimeRangeProvider)},
  onSelectionChanged: (selected) {
    ref.read(dashboardTimeRangeProvider.notifier).state = selected.first;
  },
)
```

**Placement:** Between `MaintenanceCard` and bodyweight graph section label.

---

## Testing

### Manual testing
1. Dashboard loads → toggle shows "1M" selected
2. Tap "6M" → toggle updates, "6M" highlighted
3. Tap "All" → toggle updates, "All" highlighted
4. Restart app → toggle resets to "1M"
5. Test in dark mode → toggle visible and usable

### Widget tests
Extend `test/features/dashboard/dashboard_screen_test.dart`:
```dart
testWidgets('time range toggle defaults to 1 month', (tester) async {
  await pumpDashboard(tester, buildDashboard([], targets, goals: goals));
  expect(find.text('1M'), findsOneWidget);
  // Verify "1M" segment is selected (check for visual indicator)
});

testWidgets('toggle switches time range', (tester) async {
  await pumpDashboard(tester, buildDashboard([], targets, goals: goals));
  
  await tester.tap(find.text('6M'));
  await tester.pumpAndSettle();
  
  // Verify "6M" is now selected
});
```

---

## Files to Create

| File | Purpose |
|------|---------|
| `lib/providers/dashboard_time_range_provider.dart` | Enum + StateProvider (~10 lines) |

---

## Files to Modify

| File | Changes |
|------|---------|
| `lib/features/dashboard/dashboard_screen.dart` | Add SegmentedButton toggle (~20 lines) |

---

## Definition of Done

- [ ] `TimeRange` enum created
- [ ] `dashboardTimeRangeProvider` created and defaults to `oneMonth`
- [ ] Toggle UI renders above both graphs
- [ ] Toggle switches between all 3 options
- [ ] Resets to 1 month on app restart
- [ ] Works in light and dark themes
- [ ] `flutter analyze` passes with zero issues
- [ ] Manual testing completed

---

## References

- `lib/providers/data_trigger_provider.dart` — StateProvider pattern reference
- Material 3 `SegmentedButton` documentation
- DISCOVERY.md — user decision: not persistent
