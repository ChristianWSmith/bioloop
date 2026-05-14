# T7: Fix height conversion toggle (goals + onboarding)

## Status

| Field | Value |
|-------|-------|
| Priority | High |
| Complexity | Trivial |
| Files changed | 2 |
| Lines changed | 2 |
| Risk | Low — 1-line fix in each file, same pattern |

## Context

Toggling imperial↔metric on the goals screen produces cascading corruption:

```
Start: 6'4"
→ toggle to metric: 76 cm  (should be 193 cm)
→ toggle to imperial: 2'6" (should be 6'4")
```

Same bug in onboarding screen (copy-pasted code).

**Root cause:** Both files call `UnitPreferences.metric().heightCm(inches)` which is the identity function (divides by `heightFactor: 1.0`). The fix is `UnitPreferences.imperial().heightCm(inches)` which correctly divides by 0.393701 (× 2.54).

See `DISCOVERY.md §3` for full trace.

## Intent

Fix the height conversion formula so toggling units preserves the height value. Fix both files so onboarding doesn't save corrupted data.

## Changes

**File 1:** `lib/features/goals/goals_screen.dart` line 224

```dart
// Before:
final heightCm = UnitPreferences.metric().heightCm(feet * 12 + inches);
// After:
final heightCm = UnitPreferences.imperial().heightCm(feet * 12 + inches);
```

**File 2:** `lib/features/onboarding/onboarding_screen.dart` line 144

Same change.

## Testing

- Update `goals_screen_test.dart` `'units toggle switches height fields'` test:
  - Set feet=6, inches=4 in imperial mode
  - Toggle to metric → assert height field reads `"193.0"` (not `"76.0"`)
  - Toggle back to imperial → assert feet=6, inches=4
- Add equivalent round-trip test to `onboarding_screen_test.dart`
- All existing tests continue to pass

## Dependencies

None. Independent of T6 and T8.
