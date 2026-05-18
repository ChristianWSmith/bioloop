# Ticket 11: Add proteinBasis column and UnitPreferences helpers

**Category:** Macro Settings
**Status:** Pending
**Depends on:** None
**Blocks:** Tickets 12, 13

## Problem

Protein is always calculated as `g/lb bodyweight × weightLb`. There is no option to set protein based on height (g/cm), which is a better metric for users with high body fat percentages.

## Context

- `lib/core/database/tables/user_goals.dart:7` — current `proteinGPerLb` column
- `lib/providers/unit_preferences_provider.dart:30-33` — current protein conversion helpers (`proteinDisplayFactor`, `proteinUnit`, `displayProteinGPerLb`, `proteinGPerLbFromDisplay`)
- `lib/providers/macro_targets_provider.dart:62-64` — protein calculation: `weightLb * proteinGPerLb`
- Schema version is 1 with `onCreate` only — no migration needed since the app hasn't been published

## Changes Required

### Database

Add a new column to `UserGoals` table:

```dart
TextColumn get proteinBasis => text().withDefault(const Constant('bodyweight'))();
```

Values: `'bodyweight'` or `'height'`. Default is `'bodyweight'` for backward compatibility.

### UnitPreferences

Add a helper method:

```dart
String proteinUnitForBasis(String basis) {
  if (basis == 'height') return 'g/cm';
  return useImperial ? 'g/lb' : 'g/kg';
}
```

The slider range (0.5–2.0) stays the same regardless of basis — only the unit label changes.

### Regenerate drift code

Run `dart run build_runner build` to regenerate `database.g.dart` with the new column.

## Acceptance Criteria

- [ ] `proteinBasis` column exists in `UserGoals` table with default value `'bodyweight'`
- [ ] `UnitPreferences.proteinUnitForBasis('bodyweight')` returns `'g/lb'` (imperial) or `'g/kg'` (metric)
- [ ] `UnitPreferences.proteinUnitForBasis('height')` returns `'g/cm'`
- [ ] Drift code is regenerated (`database.g.dart` includes `proteinBasis`)
- [ ] `flutter analyze` passes with zero issues

## Testing

- Unit test: `UnitPreferences.imperial().proteinUnitForBasis('bodyweight')` == `'g/lb'`
- Unit test: `UnitPreferences.metric().proteinUnitForBasis('bodyweight')` == `'g/kg'`
- Unit test: `UnitPreferences.imperial().proteinUnitForBasis('height')` == `'g/cm'`
- Unit test: `UnitPreferences.metric().proteinUnitForBasis('height')` == `'g/cm'`
- DB test: new `UserGoals` row has `proteinBasis == 'bodyweight'` by default

## Files Affected

- `lib/core/database/tables/user_goals.dart` — add `proteinBasis` column
- `lib/providers/unit_preferences_provider.dart` — add `proteinUnitForBasis()` method
- `lib/core/database/database.g.dart` — regenerated (do not edit manually)
