# Ticket 2: Clamp Calorie Targets to Non-Negative Values

**Priority:** High (correctness/safety)  
**Risk:** Low  
**Effort:** ~30 minutes  
**Status:** ⬜ Pending  

---

## Context

If the calculated maintenance calories are very low and the user has a large deficit, the final target calories could be negative. This is physically impossible — users cannot consume negative calories.

From `issues.txt`:
> ALL calculated calories AFTER applying the adjustment should be non-negative. this is very unlikely to be an issue, but if the user is aiming for a -500 calorie deficit, and either the regression algorithm or the standard fallback algorithm calculate a maintenance value of less than 500, the final daily caloric target should go to 0. again, extremely unlikely to happen, but its literally impossible to consume negative calories, so we should account for it.

**Example scenario:**
- Calculated maintenance: 400 kcal (extremely low BMR user)
- User deficit goal: -500 kcal
- Current result: 400 + (-500) = -100 kcal ❌
- Expected result: 0 kcal ✓

---

## Current State

**File:** `lib/providers/macro_targets_provider.dart`

The `MacroTargets.compute()` method has three calculation paths:

1. **Regression maintenance** (line 38-40):
   ```dart
   targetCalories = regressionMaintenance + adjustment;
   ```

2. **Mifflin-St Jeor fallback** (line 41-49):
   ```dart
   final estimated = estimateMaintenance(...);
   targetCalories = estimated + adjustment;
   ```

3. **Pre-onboarding safe floor** (line 50):
   ```dart
   targetCalories = adjustment > 1200 ? adjustment : 1200;
   ```

Only path 3 has a safety floor (1200). Paths 1 and 2 can produce negative values.

---

## Required Changes

**File:** `lib/providers/macro_targets_provider.dart`

**After line 50** (after the if/else block), add:

```dart
targetCalories = max(0.0, targetCalories);
```

**Import:** `dart:math` is already available via the existing imports.

**Location in method:**
```dart
static MacroTargets compute({
  required UserGoal? goals,
  required double? weightKg,
  required double? regressionMaintenance,
}) {
  final adjustment = goals?.calorieAdjustment ?? 0;
  final rate = adjustment * 7 / 3500;

  double targetCalories;
  double? maintenanceCalories;

  if (regressionMaintenance != null) {
    targetCalories = regressionMaintenance + adjustment;
    maintenanceCalories = regressionMaintenance;
  } else if (goals?.onboardingCompleted == 1 && ...) {
    final estimated = estimateMaintenance(...);
    targetCalories = estimated + adjustment;
    maintenanceCalories = estimated;
  } else {
    targetCalories = adjustment > 1200 ? adjustment : 1200;
  }

  // ← ADD CLAMP HERE
  targetCalories = max(0.0, targetCalories);

  // ... rest of method (protein/fat/carbs calculation)
}
```

---

## Acceptance Criteria

- [ ] Target calories never negative, even with extreme deficits
- [ ] Normal deficits (e.g., -500 from 2500 maintenance) produce correct positive targets
- [ ] Zero target when maintenance + adjustment < 0
- [ ] `flutter analyze` passes with zero issues
- [ ] All existing tests pass
- [ ] New tests verify boundary conditions

---

## Testing

### Unit Tests to Add

**File:** `test/providers/macro_targets_provider_test.dart`

**Test 1: Regression path with extreme deficit**
```dart
test('target calories clamped to 0 when deficit exceeds regression maintenance', () {
  final goals = goal(calorieAdjustment: -500);
  final targets = MacroTargets.compute(
    goals: goals,
    weightKg: 80,
    regressionMaintenance: 400,  // Very low maintenance
  );

  expect(targets.targetCalories, 0.0);  // Clamped from -100 to 0
  expect(targets.maintenanceCalories, 400);  // Maintenance still reported
});
```

**Test 2: Mifflin-St Jeor path with extreme deficit**
```dart
test('target calories clamped to 0 when Mifflin-St Jeor estimate is very low', () {
  final goals = goal(
    onboardingCompleted: 1,
    calorieAdjustment: -1000,  // Extreme deficit
    sex: 'female',
    heightCm: 150,
    birthdate: '1950-01-01',  // Elderly, low BMR
    activityLevel: 1,  // Sedentary
  );
  final targets = MacroTargets.compute(
    goals: goals,
    weightKg: 50,  // Low bodyweight
    regressionMaintenance: null,
  );

  expect(targets.targetCalories, greaterThanOrEqualTo(0.0));
});
```

**Test 3: Normal deficit not affected**
```dart
test('normal deficit produces correct positive target (not clamped)', () {
  final goals = goal(calorieAdjustment: -500);
  final targets = MacroTargets.compute(
    goals: goals,
    weightKg: 80,
    regressionMaintenance: 2500,
  );

  expect(targets.targetCalories, closeTo(2000, 1));  // Not clamped
});
```

### Commands
```bash
flutter analyze
flutter test test/providers/macro_targets_provider_test.dart
```

---

## Files to Modify

| File | Lines Changed | Type |
|------|---------------|------|
| `lib/providers/macro_targets_provider.dart` | 2 (1 import if needed, 1 clamp) | Production |
| `test/providers/macro_targets_provider_test.dart` | ~40 | Test |

**Total:** 2 production lines, ~40 test lines

---

## Implementation Notes

- The clamp should happen AFTER all three calculation branches
- The clamp only affects `targetCalories`, not `maintenanceCalories`
- Maintenance should still be reported accurately (even if target is 0)
- Protein/fat/carbs calculations use `targetCalories`, so they'll adapt to the clamped value
- This is a defensive fix — the scenario is extremely unlikely but important for correctness

---

## References

- `DISCOVERY.md` — Issue 5 section
- `lib/providers/macro_targets_provider.dart:38-70` — Current calculation logic
- `test/providers/macro_targets_provider_test.dart:12-70` — Existing test structure
- `issues.txt:5` — Original issue
