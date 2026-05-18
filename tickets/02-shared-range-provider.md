# Ticket 02: Create shared dashboard range provider

**Category:** Dashboard Sparklines
**Status:** Pending
**Depends on:** Ticket 01
**Blocks:** Ticket 03

## Problem

Both `BodyweightSparkline` and `CaloriesSparkline` compute their time ranges independently using copy-pasted logic. Because each dataset has different earliest data points, the two sparklines show different timespans even when the user selects the same toggle. There is no coordination between them.

Current independent computation (identical in both widgets):
```dart
final calculatedStart = switch (timeRange) {
  TimeRange.oneMonth => now.subtract(const Duration(days: 30)),
  TimeRange.sixMonths => now.subtract(const Duration(days: 180)),
  TimeRange.allTime => DateTime(2000, 1, 1),
};
final earliestData = DateTime.parse(sorted.first.loggedAt);
final effectiveStart = earliestData.isAfter(calculatedStart) ? earliestData : calculatedStart;
```

## Context

- `lib/features/dashboard/widgets/bodyweight_sparkline.dart:31-46` — bodyweight range computation
- `lib/features/dashboard/widgets/calories_sparkline.dart:27-44` — calorie range computation (identical logic)
- `lib/providers/dashboard_time_range_provider.dart` — `enum TimeRange { oneMonth, sixMonths, allTime }`
- `lib/features/dashboard/dashboard_screen.dart:140-151` — time range toggle UI
- `lib/features/dashboard/dashboard_screen.dart:166,181` — sparklines are passed `entries` directly with no range info

## Changes Required

Create a new `FutureProvider` that:

1. Watches `bodyweightProvider`, calorie data (via the new range-aware provider from Ticket 01), and `dashboardTimeRangeProvider`
2. Finds the earliest and latest data points across BOTH datasets
3. Computes the shared `effectiveStart` and `effectiveEnd`:
   - `calculatedStart` based on selected `TimeRange`
   - `effectiveStart = max(calculatedStart, min(earliestWeight, earliestCalories))`
   - `effectiveEnd = max(latestWeight, latestCalories, today)` — always includes today
4. Computes shared `maxDays` and `xInterval` based on the effective range
5. Returns a record: `({DateTime start, DateTime end, double maxDays, int xInterval})`

Update `DashboardScreen` to watch this provider and pass the computed values to both sparklines.

## Acceptance Criteria

- [ ] Both sparklines receive identical `start`, `end`, and `maxDays` values from a single source
- [ ] When data range < requested range, the graph shows the actual data range (not empty space)
- [ ] X-axis interval is computed once and shared between both sparklines
- [ ] Time range toggle (1M/6M/All) still works and affects both sparklines equally
- [ ] `flutter analyze` passes with zero issues

## Testing

- Test: with weight data from Jan 1 and calorie data from May 1, selecting "1M" shows May 1–today (not Jan 1–today)
- Test: with weight data from May 1 and calorie data from Jan 1, selecting "1M" shows Jan 1–today
- Test: selecting "All" with 14 days of data shows exactly 14 days (not stretched to year 2000)
- Test: both sparklines have the same X-axis labels after range computation

## Files Affected

- `lib/providers/shared_dashboard_range_provider.dart` — new file
- `lib/features/dashboard/dashboard_screen.dart` — watch new provider, pass range to sparklines
