# Ticket 13: Add protein basis toggle to goals screen + update MacroTargets

**Category:** Macro Settings
**Status:** Pending
**Depends on:** Tickets 11, 12
**Blocks:** None

## Problem

The goals screen lacks the protein basis toggle, and `MacroTargets.compute` only supports bodyweight-based protein calculation. Both need to be updated to support height-based protein.

## Context

- `lib/features/goals/goals_screen.dart:32` — `_proteinGPerLb = 1.0` state variable
- `lib/features/goals/goals_screen.dart:84` — loaded from DB: `_proteinGPerLb = goals.proteinGPerLb`
- `lib/features/goals/goals_screen.dart:462-480` — protein slider UI (identical to onboarding)
- `lib/features/goals/goals_screen.dart:220-274` — `_save()` persists goals
- `lib/providers/macro_targets_provider.dart:62-64` — protein calculation: `weightLb * proteinGPerLb`
- `lib/providers/macro_targets_provider.dart:86-103` — `macroTargetsProvider` watches `userGoalsProvider`, `bodyweightProvider`, `maintenanceProvider`

## Changes Required

### Goals Screen — Add toggle

Add state variable:
```dart
String _proteinBasis = 'bodyweight';
```

Load from DB in `_loadGoals()`:
```dart
_proteinBasis = goals.proteinBasis;  // line ~84, after _proteinGPerLb
```

Add identical toggle above protein slider (perfect UI parity with onboarding, Ticket 12):
```dart
SegmentedButton<String>(
  segments: const [
    ButtonSegment(value: 'bodyweight', label: Text('Per lb bodyweight')),
    ButtonSegment(value: 'height', label: Text('Per cm height')),
  ],
  selected: {_proteinBasis},
  onSelectionChanged: (v) => setState(() => _proteinBasis = v.first),
),
```

Update slider label and recommended range text (same logic as onboarding).

Save in `_save()`:
```dart
proteinBasis: Value(_proteinBasis),
```

### MacroTargets.compute — Height-based calculation

Update the protein calculation logic:

```dart
// Before (lines 62-64):
final proteinGPerLb = goals?.proteinGPerLb ?? 1.0;
final weightLb = weightKg != null ? weightKg * 2.20462 : 0.0;
final proteinGrams = weightLb * proteinGPerLb;

// After:
final proteinBasis = goals?.proteinBasis ?? 'bodyweight';
final proteinValue = goals?.proteinGPerLb ?? 1.0;

double proteinGrams;
if (proteinBasis == 'height') {
  final heightCm = goals?.heightCm;
  if (heightCm != null && heightCm > 0) {
    proteinGrams = heightCm * proteinValue;
  } else {
    // Fall back to bodyweight if height is not set
    final weightLb = weightKg != null ? weightKg * 2.20462 : 0.0;
    proteinGrams = weightLb * proteinValue;
  }
} else {
  final weightLb = weightKg != null ? weightKg * 2.20462 : 0.0;
  proteinGrams = weightLb * proteinValue;
}
```

### Tests

Update `UserGoal` factory helpers in test files to include `proteinBasis` field.

Add new tests:
- Height-based protein: 175cm × 1.0 g/cm = 175g protein/day
- Bodyweight-based protein: 80kg × 2.20462 × 1.0 g/lb = 176g protein/day (unchanged)
- Null heightCm falls back to bodyweight calculation
- Goals screen toggle persists after save and reopen

## Acceptance Criteria

- [ ] Goals screen toggle matches onboarding toggle exactly (labels, position, behavior)
- [ ] Height-based protein: 175cm × 1.0 g/cm = 175g protein/day
- [ ] Bodyweight-based protein: 80kg × 1.0 g/lb = 176.4g protein/day (unchanged from current)
- [ ] Null `heightCm` falls back to bodyweight calculation
- [ ] Saved `proteinBasis` persists after save and reopen
- [ ] All existing tests pass with updated `UserGoal` factories
- [ ] `flutter analyze` passes with zero issues

## Testing

New tests:
- `test/providers/macro_targets_provider_test.dart`: height-based protein calculation test
- `test/providers/macro_targets_provider_test.dart`: null heightCm fallback test
- `test/features/goals/goals_screen_test.dart`: toggle persistence test
- `test/features/goals/goals_screen_test.dart`: toggle saves correct value to DB

Updated tests:
- `test/providers/macro_targets_provider_test.dart`: `UserGoal` factory needs `proteinBasis` field
- `test/features/goals/goals_screen_test.dart`: `seedGoals()` needs `proteinBasis` field
- `test/features/dashboard/dashboard_screen_test.dart`: `makeGoals()` helper needs `proteinBasis` field

## Files Affected

- `lib/features/goals/goals_screen.dart` — add toggle, load/save `proteinBasis`, update labels
- `lib/providers/macro_targets_provider.dart` — add height-based protein calculation
- `test/providers/macro_targets_provider_test.dart` — add height-based tests, update factories
- `test/features/goals/goals_screen_test.dart` — add toggle tests, update seed helpers
- `test/features/dashboard/dashboard_screen_test.dart` — update `makeGoals()` helper
