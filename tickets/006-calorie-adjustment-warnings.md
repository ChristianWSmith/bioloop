# 006 — Add calorie adjustment warnings for aggressive deficits/surpluses

- **Phase**: 2 — Onboarding Improvements
- **Priority**: Medium

## Overview

Issue a warning when the user enters a calorie deficit below -500 or a surplus above +300. The warning should be informational only — the user can still proceed with the value. This applies to both onboarding and goals screens.

## Context from Discovery

- Onboarding and goals screens have a "Calorie adjustment" `TextFormField` whose default depends on goal type: Cut = -500, Maintain = 0, Bulk = +300.
- `_ratePreview()` helper converts adjustment to lb/week: `adjustment * 7 / 3500`. Shows "~X lb/week loss", "~X lb/week gain", or "Maintenance".
- No warning currently exists for values outside the -500 to +300 range.
- Design rule says "Disable, don't validate" — we should NOT block the user, just warn.
- Appropriate UX: a small warning text (`Text` in warning color, not a dialog) that appears below or next to the field when the value is outside the recommended range.

## Files to Modify

| File | Change |
|------|--------|
| `lib/features/onboarding/onboarding_screen.dart` | Add warning text widget near calorie adjustment field, shown when `adjustment < -500` or `adjustment > 300` |
| `lib/features/goals/goals_screen.dart` | Same warning text widget |

## Acceptance Criteria

- [ ] Warning text appears when calorie adjustment < -500
- [ ] Warning text appears when calorie adjustment > 300
- [ ] Warning text disappears when adjustment is within [-500, 300]
- [ ] Warning text is informational (colored, e.g., `colorScheme.tertiary` or orange) — not a blocking dialog
- [ ] User can still save with values outside the range
- [ ] Warning shows on both onboarding and goals screens
- [ ] `flutter analyze` passes with zero errors
- [ ] Existing tests pass

## Testing

- Widget test: warning is absent at default values (Cut = -500, Maintain = 0, Bulk = +300)
- Widget test: warning appears when typing -600
- Widget test: warning appears when typing +400
- Widget test: warning disappears when correcting back to -500
- Widget test: save button remains active even with warning visible
