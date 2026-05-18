# Ticket 12: Add protein basis toggle to onboarding screen

**Category:** Macro Settings
**Status:** Pending
**Depends on:** Ticket 11
**Blocks:** Ticket 13

## Problem

The onboarding screen only offers bodyweight-based protein. Users with high body fat percentages need a height-based alternative.

## Context

- `lib/features/onboarding/onboarding_screen.dart:34` — `_proteinGPerLb = 1.0` state variable
- `lib/features/onboarding/onboarding_screen.dart:484-502` — protein slider UI (label, slider, recommended range)
- `lib/features/onboarding/onboarding_screen.dart:179-193` — `_save()` persists goals to DB
- `lib/providers/unit_preferences_provider.dart` — `proteinUnitForBasis()` added in Ticket 11

## Changes Required

### Add state variable

```dart
String _proteinBasis = 'bodyweight';
```

### Add toggle above protein slider

Insert a `SegmentedButton<String>` between the calorie warning (line 483) and the protein label (line 484):

```dart
SegmentedButton<String>(
  segments: const [
    ButtonSegment(value: 'bodyweight', label: Text('Per lb bodyweight')),
    ButtonSegment(value: 'height', label: Text('Per cm height')),
  ],
  selected: {_proteinBasis},
  onSelectionChanged: (v) => setState(() => _proteinBasis = v.first),
),
const SizedBox(height: 12),
```

### Update protein slider label

Change line 485:
```dart
// Before:
'Protein: ${_unitPrefs.displayProteinGPerLb(_proteinGPerLb).toStringAsFixed(1)} ${_unitPrefs.proteinUnit}'

// After:
'Protein: ${_unitPrefs.displayProteinGPerLb(_proteinGPerLb).toStringAsFixed(1)} ${_unitPrefs.proteinUnitForBasis(_proteinBasis)}'
```

### Update recommended range text

Change lines 497-502:
```dart
// Before:
'Recommended: ${_unitPrefs.displayProteinGPerLb(0.8).toStringAsFixed(1)}\u2013${_unitPrefs.displayProteinGPerLb(1.4).toStringAsFixed(1)} ${_unitPrefs.proteinUnit}'

// After:
if (_proteinBasis == 'bodyweight')
  'Recommended: ${_unitPrefs.displayProteinGPerLb(0.8).toStringAsFixed(1)}\u2013${_unitPrefs.displayProteinGPerLb(1.4).toStringAsFixed(1)} ${_unitPrefs.proteinUnitForBasis(_proteinBasis)}'
else
  'Recommended: 0.8\u20131.4 ${_unitPrefs.proteinUnitForBasis(_proteinBasis)}'
```

For height basis, the recommended range is `0.8–1.4 g/cm` directly (no conversion needed since the slider value IS g/cm).

### Save to database

In `_save()` (line 179-193), add `proteinBasis` to the `UserGoalsCompanion`:

```dart
await db.upsertGoals(UserGoalsCompanion(
  // ... existing fields ...
  proteinBasis: Value(_proteinBasis),
  // ...
));
```

## Acceptance Criteria

- [ ] Toggle renders between the calorie adjustment section and the protein slider
- [ ] Toggle has two segments: "Per lb bodyweight" and "Per cm height"
- [ ] Switching toggle updates the unit label on the slider (g/lb, g/kg, or g/cm)
- [ ] Switching toggle updates the recommended range text
- [ ] Slider range stays 0.5–2.0 regardless of basis
- [ ] Saved `proteinBasis` value persists in database
- [ ] Default value is `'bodyweight'`
- [ ] `flutter analyze` passes with zero issues

## Testing

- Widget test: toggle renders with "Per lb bodyweight" selected by default
- Widget test: tap "Per cm height" → slider label shows "g/cm"
- Widget test: tap "Per cm height" → recommended range shows "0.8–1.4 g/cm"
- Widget test: save → DB row has `proteinBasis == 'height'`
- Widget test: metric user sees "g/kg" when bodyweight basis is selected

## Files Affected

- `lib/features/onboarding/onboarding_screen.dart` — add toggle, update labels, save `proteinBasis`
