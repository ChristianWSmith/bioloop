# 001 — Fix onboarding default values

**Issues**: #1, #4
**Files**: `lib/features/onboarding/onboarding_screen.dart`
**Effort**: Trivial

---

## Context

During onboarding, the sex selection starts unselected (no default) and the goal type defaults to "Cut" with a -500 kcal adjustment. The user should have "Male" pre-selected and "Maintain" as the default goal type with a 0 kcal adjustment.

Current defaults in `_OnboardingScreenState`:
- Line 23: `String? _sex;` → null, no selection
- Line 32: `String _goalType = 'cut';`
- Line 33: `final _calorieAdjustmentController = TextEditingController(text: '-500');`

---

## Acceptance criteria

1. The sex `SegmentedButton` has "Male" selected by default on first load
2. Empty selection is not allowed — user must pick one of the two options
3. The goal type `SegmentedButton` has "Maintain" selected by default
4. When "Maintain" is the default, the calorie adjustment field shows `0`
5. All existing onboarding functionality (unit conversion, form validation, save) continues to work

---

## Implementation notes

- Initialize `_sex = 'male'` instead of `null`
- Remove `emptySelectionAllowed: true` from the sex `SegmentedButton`
- Change `_goalType = 'cut'` to `_goalType = 'maintain'`
- Change the calorie adjustment initial text to `'0'`
- Alternatively: call `_onGoalTypeChanged('maintain')` in `initState` which sets both the type and adjustment via the existing switch logic (lines 106-115)

---

## Testing

1. Launch the app fresh (no existing goals) → onboarding appears
2. Verify "Male" is pre-selected in the sex toggle
3. Verify both "Male" and "Female" can still be toggled
4. Verify "Maintain" is pre-selected in the goal type toggle
5. Verify the calorie adjustment field shows `0` when "Maintain" is selected
6. Verify switching to "Cut" changes the adjustment to `-500` and switching to "Bulk" changes it to `300`
7. Verify "Save" button enables only when all required fields are filled (sex, birthdate, height, weight)
8. Run `flutter analyze` — zero issues
