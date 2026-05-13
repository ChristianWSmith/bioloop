# 014 — Parity audit: onboarding vs goals screen

- **Phase**: 2 — Onboarding Improvements
- **Priority**: Medium

## Overview

Ensure the onboarding and goals screens are as close to identical as reasonable. Several differences have been identified (unit toggle behavior, birthdate vs age, save button behavior, slider recommendations, calorie warnings). Audit both screens for any remaining discrepancies and resolve them.

## Context from Discovery

Known gaps being addressed by other tickets:

| Gap | Ticket |
|-----|--------|
| Unit toggle doesn't control fields in onboarding | #002 |
| Age vs birthdate | #001 |
| Save button always active in onboarding | #004 |
| Slider recommended ranges missing on both | #005 |
| Calorie adjustment warnings missing on both | #006 |

Remaining items to audit:

- **Layout/field order**: Do both screens present fields in the same logical order?
- **Labels and hint text**: Are field labels and hints identical?
- **Validation rules**: Do both screens validate identically?
- **Default values**: Are defaults consistent (protein 1.0, fat 25%, activity level 3)?
- **Error handling**: Both use `AlertDialog` on error (confirmed matching).
- **Rate preview**: Both show `_ratePreview()` adjustement text (confirmed matching).
- **Goal weight**: Both allow optional goal weight (confirmed).
- **Activity level**: Both use same 5-level radio list (confirmed).
- **Goal type segmented button**: Both use same 3-option segmented button (confirmed).

## Files to Modify

| File | Change |
|------|--------|
| `lib/features/onboarding/onboarding_screen.dart` | Align layout, labels, validation with goals screen |
| `lib/features/goals/goals_screen.dart` | Any necessary changes to align with onboarding (onboarding is the simpler screen, goals may need backports) |

## Acceptance Criteria

- [ ] Both screens present fields in the same logical order (where applicable — onboarding has weight + date fields that goals doesn't)
- [ ] Field labels and hint text are identical
- [ ] Validation behavior is identical
- [ ] Default values are identical
- [ ] Error handling is identical (both use `AlertDialog`)
- [ ] Rate preview is identical
- [ ] Both use the same `_canSave` pattern for save button enable/disable
- [ ] Both handle unit toggle identically
- [ ] `flutter analyze` passes with zero errors
- [ ] Existing tests pass

## Testing

- Review: manually compare both screens' source code for differences
- Widget test: verify both screens have identical field layouts and behaviors (parameterized test)
- No regressions in existing onboarding or goals tests
