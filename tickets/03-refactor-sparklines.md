# Ticket 03: Refactor sparklines to accept range parameters

**Category:** Dashboard Sparklines
**Status:** Pending
**Depends on:** Ticket 02
**Blocks:** Ticket 04

## Problem

Both `BodyweightSparkline` and `CaloriesSparkline` contain duplicated time range computation logic: calculating `calculatedStart`, computing `effectiveStart`, filtering data, and computing `maxDays`. This duplication makes it impossible to guarantee the two sparklines show the same timespan.

## Context

- `lib/features/dashboard/widgets/bodyweight_sparkline.dart` (272 lines) — contains time range logic at lines 31-84
- `lib/features/dashboard/widgets/calories_sparkline.dart` (185 lines) — contains identical time range logic at lines 27-70
- `lib/features/dashboard/dashboard_screen.dart:166,181` — sparklines are instantiated with just `entries`

## Changes Required

**BodyweightSparkline:**
- Add constructor parameters: `required DateTime effectiveStart`, `required double maxDays`, `required int xInterval`
- Remove internal `calculatedStart`, `effectiveStart`, `maxDays`, and `_getInterval()` computation
- Remove `ref.watch(dashboardTimeRangeProvider)` — range is now passed from parent
- Filter data using the passed `effectiveStart` instead of computing it

**CaloriesSparkline:**
- Same changes as BodyweightSparkline

**DashboardScreen:**
- Watch the shared range provider (from Ticket 02)
- Pass `effectiveStart`, `maxDays`, and `xInterval` to both sparkline constructors

## Acceptance Criteria

- [ ] Both sparklines accept `effectiveStart`, `maxDays`, and `xInterval` as constructor parameters
- [ ] No duplicated time range computation logic between the two widgets
- [ ] Both sparklines render identically to before when given the same range values
- [ ] `ref.watch(dashboardTimeRangeProvider)` is removed from both sparkline widgets
- [ ] `flutter analyze` passes with zero issues

## Testing

- Widget test: render `BodyweightSparkline` with custom `effectiveStart`, verify data before that date is excluded
- Widget test: render `CaloriesSparkline` with custom `maxDays`, verify X-axis spans correct number of days
- Widget test: both sparklines given the same range produce the same X-axis interval
- Existing tests in `dashboard_screen_test.dart` should still pass (update `buildSparkline` helper to pass range params)

## Files Affected

- `lib/features/dashboard/widgets/bodyweight_sparkline.dart` — remove internal range logic, add constructor params
- `lib/features/dashboard/widgets/calories_sparkline.dart` — remove internal range logic, add constructor params
- `lib/features/dashboard/dashboard_screen.dart` — pass range params to sparklines
- `test/features/dashboard/dashboard_screen_test.dart` — update test helpers
- `test/features/dashboard/widgets/calories_sparkline_test.dart` — update tests for new constructor
