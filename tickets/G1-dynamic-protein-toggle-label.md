# G1: Dynamic "Per lb/kg bodyweight" toggle label

**Category**: Goals / Onboarding
**Priority**: Low
**Estimated effort**: Small (2 files, same pattern)
**Discovery**: `DISCOVERY.md` → G1

## Problem

The protein basis toggle shows "Per lb bodyweight" regardless of whether the user is in metric or imperial mode. Metric users should see "Per kg bodyweight".

## Root Cause

Both `GoalsScreen` and `OnboardingScreen` have hardcoded `const` segment labels in their `SegmentedButton<String>` for protein basis:

```dart
segments: const [
  ButtonSegment(value: 'bodyweight', label: Text('Per lb bodyweight')),
  ButtonSegment(value: 'height', label: Text('Per cm height')),
],
```

Both screens already have a `_useImperial` bool and a `_unitPrefs` getter that correctly computes dynamic units for the slider label, recommended range text, and slider min/max. The toggle segments are the only place where units are hardcoded.

Note: "Per cm height" is correct for both systems (height is always measured in cm internally), so only the bodyweight label needs changing.

## Proposed Fix

Remove `const` from `segments` and make the bodyweight label conditional on `_useImperial`:

```dart
segments: [
  ButtonSegment(
    value: 'bodyweight',
    label: Text('Per ${_useImperial ? "lb" : "kg"} bodyweight'),
  ),
  ButtonSegment(value: 'height', label: Text('Per cm height')),
],
```

Apply this change in both screens.

## Acceptance Criteria

- [ ] Goals screen shows "Per lb bodyweight" when imperial is selected
- [ ] Goals screen shows "Per kg bodyweight" when metric is selected
- [ ] Onboarding screen shows "Per lb bodyweight" when imperial is selected
- [ ] Onboarding screen shows "Per kg bodyweight" when metric is selected
- [ ] "Per cm height" label remains unchanged in both modes on both screens
- [ ] Toggling between metric/imperial updates the label immediately
- [ ] `flutter analyze` passes with zero issues

## Testing

### Manual testing
1. Open Goals screen with imperial selected → verify "Per lb bodyweight"
2. Switch to metric → verify label changes to "Per kg bodyweight"
3. Switch back to imperial → verify label changes to "Per lb bodyweight"
4. Repeat steps 1-3 on Onboarding screen

### Edge cases
- "Per cm height" should NOT change based on unit preference (height is always cm)
- Slider label, recommended range text, and slider min/max should continue working correctly (they already use `proteinUnitForBasis()`)

## Files to change

| File | Lines | Change |
|---|---|---|
| `lib/features/goals/goals_screen.dart` | 465-472 | Remove `const`, make bodyweight label conditional |
| `lib/features/onboarding/onboarding_screen.dart` | 486-493 | Remove `const`, make bodyweight label conditional |

## References

- `lib/providers/unit_preferences_provider.dart:35-38` — `proteinUnitForBasis()` (existing dynamic unit logic)
- `lib/features/goals/goals_screen.dart:474-494` — slider already uses dynamic units
- `lib/features/onboarding/onboarding_screen.dart:495-515` — slider already uses dynamic units
