# 003 — Remove date prompt from onboarding

- **Phase**: 2 — Onboarding Improvements
- **Priority**: Medium

## Overview

During onboarding, the user is prompted to enter the date for their starting weight log entry. This is unnecessary — we can assume "today" as the date. Remove the date picker field and use `DateTime.now()` internally when inserting the initial bodyweight entry.

## Context from Discovery

- Onboarding screen (`lib/features/onboarding/onboarding_screen.dart:229–251`) has a date field with `showDatePicker`, constrained to 2000–today, displayed as `YYYY-MM-DD` in an `InputDecorator` with a calendar icon button.
- The selected date is passed to `db.insertWeight(BodyweightEntriesCompanion(loggedAt: ...))`.
- The date field takes up space in the already-long onboarding form and adds friction.

## Files to Modify

| File | Change |
|------|--------|
| `lib/features/onboarding/onboarding_screen.dart` | Remove `_dateController`, date picker field widget, date-related state. Replace with `DateTime.now()` in the `_save()` method when inserting weight. |

## Acceptance Criteria

- [ ] Onboarding no longer shows a date field or date picker
- [ ] Initial bodyweight entry is always logged with today's date
- [ ] No date-related text fields, controllers, or state remain in onboarding screen
- [ ] `flutter analyze` passes with zero errors
- [ ] Existing tests pass

## Testing

- Widget test: onboarding screen does not contain a date field
- Verify `db.insertWeight` in onboarding `_save()` receives `DateTime.now()` (not a user-picked date)
