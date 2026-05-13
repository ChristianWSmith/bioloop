# 002 — Fix onboarding metric/imperial toggle

- **Phase**: 1 — Database Schema Changes
- **Priority**: High

## Overview

The onboarding screen has a metric/imperial toggle (`SegmentedButton<bool>`) that is purely cosmetic — it stores the preference to the database but never affects the height or weight input fields. The goals screen has a fully working implementation with bidirectional conversion. Port the goals screen pattern to onboarding.

## Context from Discovery

- Onboarding toggle (`lib/features/onboarding/onboarding_screen.dart:273–289`): `SegmentedButton<bool>` with Metric/Imperial options. Sets `_useImperial` but fields still show `suffixText: 'cm'` and `suffixText: 'kg'` unconditionally.
- Goals screen toggle (`lib/features/goals/goals_screen.dart:154–190`): `_onUnitsChanged()` converts cm ↔ ft+in for height, kg ↔ lb for goal weight, and swaps the height field widget via `_buildHeightField()` (lines 255–307).
- The toggle currently appears AFTER the weight field in onboarding. It should come BEFORE or at least control the fields above it.
- Height currently uses `_heightController` (single `TextFormField`). Needs to support both metric (cm) and imperial (ft + in as two fields in a `Row`).

## Files to Modify

| File | Change |
|------|--------|
| `lib/features/onboarding/onboarding_screen.dart` | Move toggle before height/weight fields. Implement bidirectional conversion (port from goals screen). Make height field switch between single cm field and dual ft/in fields. Make weight field switch between kg and lb. |

## Acceptance Criteria

- [ ] Toggling to imperial changes height field to two fields: feet + inches
- [ ] Toggling to metric changes height field back to single cm field
- [ ] Toggling imperial changes weight suffix to `lb` (and converts displayed value)
- [ ] Toggling metric changes weight suffix back to `kg` (and converts displayed value)
- [ ] Values are correctly converted bidirectionally (cm ↔ ft+in, kg ↔ lb)
- [ ] Stored values in DB are always in metric (cm, kg) regardless of display unit
- [ ] Toggle is positioned early in the form (before height/weight fields)
- [ ] `flutter analyze` passes with zero errors
- [ ] Existing tests pass

## Testing

- Widget test: toggle changes height field layout from single field to dual fields
- Widget test: toggle changes weight suffix text
- Widget test: entering height in imperial and toggling to metric shows correct converted value
- Widget test: entering weight in imperial and toggling to metric shows correct converted value
- Verify saved DB values are always in metric units
