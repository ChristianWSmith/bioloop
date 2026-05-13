# 004 — Disable onboarding save button until fields are filled

- **Phase**: 2 — Onboarding Improvements
- **Priority**: Medium

## Overview

The onboarding save button is always active. Per the "Disable, don't validate" design rule, it should be disabled until all required fields are filled. The goals screen already implements this pattern via a `_canSave` getter.

## Context from Discovery

- Onboarding `_save()` (`lib/features/onboarding/onboarding_screen.dart:62–122`): validates form via `_formKey.currentState!.validate()`, checks `_sex != null` (shows snackbar if missing). The `ElevatedButton` has no `onPressed` guard.
- `_save` is currently only called from the button's `onPressed` — button itself is never disabled.
- Goals screen (`lib/features/goals/goals_screen.dart`) uses `_canSave` getter that checks all fields, and the button's `onPressed` is `_canSave ? _save : null`.
- Required onboarding fields: sex, birthdate (post-ticket-001), height, starting weight, goal type, protein slider, fat slider.
- Optional: goal weight.

## Files to Modify

| File | Change |
|------|--------|
| `lib/features/onboarding/onboarding_screen.dart` | Add `_canSave` getter checking all required fields are non-empty. Bind `ElevatedButton.onPressed` to `_canSave ? _save : null`. Add visual styling for disabled state. |

## Acceptance Criteria

- [ ] Save button is disabled when any required field is empty
- [ ] Save button becomes enabled once all required fields are filled
- [ ] No snackbar/validation messages shown on tap (button simply doesn't respond)
- [ ] Per design rule: "Disable, don't validate" — never show validation errors after tap
- [ ] `flutter analyze` passes with zero errors
- [ ] Existing tests pass

## Testing

- Widget test: button is disabled when height field is empty
- Widget test: button becomes enabled when all fields filled
- Widget test: tapping disabled button does nothing (no snackbar, no dialog)
- Verify the button's `onPressed` is null when `_canSave` is false
