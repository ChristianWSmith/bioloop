# Ticket 01: Fix calorie data provider to support arbitrary date ranges

**Category:** Dashboard Sparklines
**Status:** Pending
**Depends on:** None
**Blocks:** Ticket 02

## Problem

`historicalCaloriesProvider` in `lib/providers/food_log_provider.dart:48-63` hard-codes a 30-day window:

```dart
final now = DateTime.now();
final thirtyDaysAgo = now.subtract(const Duration(days: 30));
final entries = await logService.getEntriesForDateRange(thirtyDaysAgo, now);
```

This means the "6M" and "All" time range toggles on the dashboard are non-functional for the calorie sparkline — it can never show more than 30 days of data regardless of the toggle selection. The bodyweight sparkline works correctly for all ranges because `bodyweightProvider` returns ALL weight entries with no date filter.

Additionally, `lib/providers/historical_calories_provider.dart` exists as a standalone file with an identical `historicalCaloriesProvider` definition. It is NOT imported anywhere — `dashboard_screen.dart` imports from `food_log_provider.dart`. This is dead code.

## Context

- `lib/providers/food_log_provider.dart:48-63` — current `historicalCaloriesProvider` definition
- `lib/providers/historical_calories_provider.dart` — dead duplicate file
- `lib/core/database/database.dart:165-174` — `getEntriesForDateRange()` already supports arbitrary ranges
- `lib/features/dashboard/widgets/calories_sparkline.dart:27-32` — sparkline computes `calculatedStart` but the data source never provides data beyond 30 days

## Changes Required

1. Modify `historicalCaloriesProvider` to be a `FutureProvider.family` that accepts `(DateTime start, DateTime end)` parameters
2. Keep a convenience non-parameterized default that fetches 30 days (for backward compatibility with any other callers)
3. Delete `lib/providers/historical_calories_provider.dart`

## Acceptance Criteria

- [ ] `historicalCaloriesProvider` can fetch calorie data for any date range passed as parameters
- [ ] A default (non-parameterized) version still exists that returns 30 days of data
- [ ] `lib/providers/historical_calories_provider.dart` is deleted
- [ ] `flutter analyze` passes with zero issues
- [ ] All existing tests pass

## Testing

- Add provider test: fetch calorie data for a 180-day range, verify entries outside 30 days are included
- Add provider test: fetch calorie data for a 1-day range, verify only that day's entries are returned
- Verify existing `todaysFoodProvider` and `dateFoodProvider` tests still pass (not affected)

## Files Affected

- `lib/providers/food_log_provider.dart` — modify `historicalCaloriesProvider`
- `lib/providers/historical_calories_provider.dart` — delete
