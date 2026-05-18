# D2: Calories sparkline should include today's data

**Category**: Dashboard
**Priority**: Medium
**Estimated effort**: Small (1 file, 1 line)
**Discovery**: `DISCOVERY.md` → D2

## Problem

The calories consumed sparkline on the dashboard does not show today's calorie data, even when food has been logged today.

## Root Cause

`getEntriesForDateRange()` in `lib/core/database/database.dart:165-174` formats the `end` parameter as a date-only string (e.g. `"2026-05-18"`) and uses `isBetweenValues(startStr, endStr)` for the query.

The `loggedAt` column stores timestamps with time components (e.g. `"2026-05-18 14:30:00"`). Since the comparison is lexicographic:

```
"2026-05-18 14:30:00" > "2026-05-18"
```

All of today's entries fail the `<= endStr` check and are excluded.

### Data flow

1. `dashboard_screen.dart:63-67` — `DashboardRange.compute()` sets `range.end` to today (midnight)
2. `dashboard_screen.dart:69-74` — `historicalCaloriesProvider(start, end)` is called
3. `food_log_provider.dart:52` — calls `getEntriesForDateRange(start, end)`
4. `database.dart:165-174` — formats `end` as date-only, uses `isBetweenValues`

## Proposed Fix

In `lib/core/database/database.dart`, change the end boundary to `end.add(const Duration(days: 1))` so the formatted string becomes `"2026-05-19"`, which captures all timestamps on the end date:

```dart
// Before
final endStr = '${end.year}-${end.month.toString().padLeft(2, '0')}-${end.day.toString().padLeft(2, '0')}';

// After
final endExclusive = end.add(const Duration(days: 1));
final endStr = '${endExclusive.year}-${endExclusive.month.toString().padLeft(2, '0')}-${endExclusive.day.toString().padLeft(2, '0')}';
```

### Caller impact

Current callers of `getEntriesForDateRange()`:
- `historicalCaloriesProvider` (`food_log_provider.dart:52`) — wants inclusive end
- `historicalCalories30DaysProvider` (`food_log_provider.dart:66`) — wants inclusive end

Both callers benefit from this fix; neither relies on exclusive-end behavior.

## Acceptance Criteria

- [ ] The calories sparkline displays today's logged food data when food has been logged today
- [ ] The sparkline still correctly displays historical data (yesterday, last week, etc.)
- [ ] No regression in `historicalCalories30DaysProvider` (used elsewhere in the app)
- [ ] `flutter analyze` passes with zero issues

## Testing

### Manual testing
1. Log a food item for today
2. Navigate to Dashboard
3. Verify the calories sparkline shows a data point for today's date

### Edge cases
- No food logged today → sparkline shows last logged day as most recent point
- Food logged at midnight (00:00:00) → still included
- Food logged at 23:59:59 → still included

## Files to change

| File | Lines | Change |
|---|---|---|
| `lib/core/database/database.dart` | 165-174 | Add 1 day to `end` before formatting |

## References

- `lib/core/database/database.dart:165-174` — `getEntriesForDateRange()`
- `lib/providers/food_log_provider.dart:48-61` — `historicalCaloriesProvider`
- `lib/features/dashboard/widgets/calories_sparkline.dart` — sparkline widget
