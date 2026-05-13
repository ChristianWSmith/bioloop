# 005 — Highlight recommended ranges on protein/fat sliders

- **Phase**: 2 — Onboarding Improvements
- **Priority**: Medium

## Overview

Add visual indicators for recommended ranges on the protein and fat sliders in both onboarding and goals screens. This helps users understand what values are typically recommended without restricting their choices — values are still clamped per the existing slider ranges.

## Context from Discovery

- Protein slider: `min: 0.5, max: 2.0, divisions: 30` (0.05 increments). Displayed as `g/lb`.
- Fat slider: `min: 10, max: 50, divisions: 40` (1% increments). Displayed as `% of calories`.
- Current sliders have no visual indication of "recommended" zone.
- Typical recommendations: protein 0.8–1.2 g/lb, fat 20–35% of calories.
- Both onboarding screen (`lib/features/onboarding/onboarding_screen.dart:359–381`) and goals screen (`lib/features/goals/goals_screen.dart:442–479`) have identical sliders.
- Flutter's `Slider` widget supports `SliderThemeData` with `activeTrackColor`, `inactiveTrackColor`, `overlayShape`, etc. Colored track segments can be simulated with `SliderTheme` overlays or by using a different widget.

## Implementation Options

1. **Colored track**: Use `SliderTheme` to make the recommended range a different color on the track (requires `LinearGradient` on track or custom `SliderTrackShape`).
2. **Overlay ticks**: Add `divisions` that highlight recommended range with different tick spacing.
3. **Helper text**: Show label below slider: "Recommended: 0.8–1.2 g/lb" with current value colored green if in range, amber if outside.

## Files to Modify

| File | Change |
|------|--------|
| `lib/features/onboarding/onboarding_screen.dart` | Add recommended range indicator to both sliders |
| `lib/features/goals/goals_screen.dart` | Add recommended range indicator to both sliders |

## Acceptance Criteria

- [ ] Protein slider shows recommended range (0.8–1.2 g/lb) visually
- [ ] Fat slider shows recommended range (20–35%) visually
- [ ] Visual indicator does not prevent user from dragging to any value within min/max
- [ ] Implementation is consistent between onboarding and goals screens
- [ ] `flutter analyze` passes with zero errors
- [ ] Existing tests pass

## Testing

- Widget test: slider exists with correct min/max/divisions
- Visual test: recommended range indicator is rendered (specific assertion depends on chosen implementation)
