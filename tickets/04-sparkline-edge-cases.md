# Ticket 04: Add sparkline edge cases (single-point extension, today inclusion)

**Category:** Dashboard Sparklines
**Status:** Pending
**Depends on:** Ticket 03
**Blocks:** None

## Problem

Two edge cases are not handled in the shared range computation:

1. **Single-point same-day extension:** When both sparklines have exactly 1 data point on the same day (brand new user), the range should extend back 1 day so the graph has visible width. Example: first weight + first food entry on May 2 → range should be May 1–May 2.

2. **Today inclusion for calories:** The calorie sparkline's end date should always include today, even if no food was logged today. This ensures the X-axis extends to the current day.

## Context

- `lib/providers/shared_dashboard_range_provider.dart` — where the shared range is computed (created in Ticket 02)
- `lib/features/dashboard/widgets/calories_sparkline.dart` — calorie sparkline that needs today on X-axis
- `lib/features/dashboard/widgets/bodyweight_sparkline.dart` — weight sparkline

## Changes Required

In the shared range provider's computation:

1. **Single-point extension:** After computing `effectiveStart` and `effectiveEnd`, check if both datasets have exactly 1 point and both points fall on the same date. If so, set `effectiveStart = thatDate - 1 day`.

2. **Today inclusion:** Ensure `effectiveEnd` is at least `DateTime.now()` (today at midnight). This means even if the latest food entry was yesterday, the X-axis extends to today.

3. Update `maxDays` to account for any range extension from these edge cases.

## Acceptance Criteria

- [ ] New user with 1 weight + 1 food entry on same day sees a 2-day range (day before → that day)
- [ ] Calorie sparkline X-axis always extends to today, even with no food logged today
- [ ] Weight sparkline X-axis matches calorie sparkline X-axis (same end date)
- [ ] Normal multi-point data is unaffected by these edge case rules
- [ ] `flutter analyze` passes with zero issues

## Testing

- Unit test: single weight on May 2 + single calorie entry on May 2 → effectiveStart = May 1, effectiveEnd = May 2
- Unit test: single weight on May 2 + single calorie entry on May 1 → no extension (different dates)
- Unit test: multiple entries with latest on May 15 → effectiveEnd = today (May 18), not May 15
- Unit test: empty datasets → no crash, returns sensible defaults

## Files Affected

- `lib/providers/shared_dashboard_range_provider.dart` — add edge case logic
- `test/providers/shared_dashboard_range_provider_test.dart` — new test file
