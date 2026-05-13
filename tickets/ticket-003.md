# Ticket 003 — Create global unit preference provider

**Issues:** #2 (infrastructure)
**Estimate:** ~1 hr
**Depends on:** nothing

---

## Acceptance criteria

- [ ] New `unitPreferencesProvider` exists in `lib/providers/unit_preferences_provider.dart`
- [ ] Provider exposes a `UnitPreferences` data class with: `useImperial`, `weightFactor`, `weightUnit`, `heightFactor`, `heightUnit`
- [ ] Provider is derived from `userGoalsProvider`, watching `resetTriggerProvider` for reactivity
- [ ] `dashboard_screen.dart` and `bodyweight_sparkline.dart` updated to read from the new provider (replaces inline `useImperial` reads from `userGoalsProvider`)
- [ ] No visible behavior changes — this is a pure refactoring ticket
- [ ] `flutter analyze` passes with zero errors
- [ ] All existing tests pass

---

## Context from DISCOVERY.md

### Problem

Currently `useImperial` is read ad-hoc from `userGoalsProvider` by screens that need it. There is no single source of truth for unit conversion factors and labels. This leads to:
- Inconsistent conversion factor usage (some places hardcode `2.20462`, others may differ)
- Each screen independently extracts `goals.useImperial == 1`
- No easy way to update all unit displays from one place

### Design

```dart
// lib/providers/unit_preferences_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'goals_provider.dart';
import 'reset_provider.dart';

class UnitPreferences {
  final bool useImperial;
  final double weightFactor;   // 2.20462 or 1.0
  final String weightUnit;     // 'lb' or 'kg'
  final double heightFactor;   // 0.393701 (in/cm) or 1.0 — but height uses ft+in, not a simple multiplier
  final String heightUnit;     // 'ft/in' or 'cm'

  const UnitPreferences({
    required this.useImperial,
    required this.weightFactor,
    required this.weightUnit,
    required this.heightFactor,
    required this.heightUnit,
  });

  // Weight conversion helpers
  double displayWeight(double kg) => kg * weightFactor;
  double kgWeight(double display) => display / weightFactor;

  factory UnitPreferences.metric() => const UnitPreferences(
        useImperial: false,
        weightFactor: 1.0,
        weightUnit: 'kg',
        heightFactor: 1.0,
        heightUnit: 'cm',
      );

  factory UnitPreferences.imperial() => const UnitPreferences(
        useImperial: true,
        weightFactor: 2.20462,
        weightUnit: 'lb',
        heightFactor: 0.393701, // in per cm
        heightUnit: 'ft/in',
      );

  factory UnitPreferences.fromGoals(UserGoal? goals) {
    return goals?.useImperial == 1
        ? UnitPreferences.imperial()
        : UnitPreferences.metric();
  }
}

final unitPreferencesProvider = Provider<UnitPreferences>((ref) {
  ref.watch(resetTriggerProvider);
  final goals = ref.watch(userGoalsProvider).valueOrNull;
  return UnitPreferences.fromGoals(goals);
});
```

Note: Height is complex because imperial height uses **two fields** (ft + in), not a single multiplier. The `heightFactor` is informational only — screens should still use the ft/in conversion logic where appropriate.

### Screens to update

| Screen | Current pattern | New pattern |
|--------|----------------|-------------|
| `dashboard_screen.dart:84` | `goals.useImperial == 1` | `ref.watch(unitPreferencesProvider).useImperial` |
| `bodyweight_sparkline.dart:17` | `goalsAsync.valueOrNull?.useImperial == 1` | `ref.watch(unitPreferencesProvider).useImperial` |

Onboarding and Goals screens maintain local `_useImperial` state for live toggle — they should read the initial value from the provider but keep local state for the toggle interaction.

---

## Testing

- No new behavior to test — verify existing tests still pass
- `flutter test` should return same results: 242 pass, 2 fail, 3 skip
- `flutter analyze` should pass clean

### Automated test ideas
- Unit test `UnitPreferences` factory constructors
- Unit test conversion helpers (`displayWeight`, `kgWeight`)

---

## Files to create/modify

- **Create:** `lib/providers/unit_preferences_provider.dart`
- **Modify:** `lib/features/dashboard/dashboard_screen.dart`
- **Modify:** `lib/features/dashboard/widgets/bodyweight_sparkline.dart`
