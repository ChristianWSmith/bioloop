# Ticket 002 — Fix height & goal weight not loading in imperial

**Issues:** #3, #9
**Estimate:** ~30 min
**Depends on:** nothing

---

## Acceptance criteria

- [ ] Goals screen loads height in imperial when `useImperial == 1` (feet/inches fields populated, not empty)
- [ ] Goals screen loads goal weight in imperial when `useImperial == 1` (lb value shown, not raw kg)
- [ ] No regression: metric loading still works correctly
- [ ] Onboarding screen unaffected (already correct — always starts fresh)

---

## Context from DISCOVERY.md

### Root cause of both bugs

**File:** `lib/features/goals/goals_screen.dart:58-83` (`_loadGoals()`)

```dart
_heightController.text = goals.heightCm?.toString() ?? '';      // line 66 — always cm
_goalWeightController.text = goals.goalWeightKg?.toString() ?? ''; // line 67 — always kg
_useImperial = goals.useImperial == 1;                           // line 68
```

The controllers are populated with raw metric values regardless of `_useImperial`. When `_useImperial` is true:
- The imperial height fields (`_heightFeetController`, `_heightInchesController`) are never populated
- The goal weight shows kg value but the suffix says "lb"

The only way to see imperial values is to toggle metric→imperial, which triggers `_onUnitsChanged()` (line 182-217) that converts the values.

### Fix

After setting `_useImperial`, populate the correct controllers:

```dart
_useImperial = goals.useImperial == 1;
if (_useImperial) {
  // Convert height cm → ft/in
  if (goals.heightCm != null) {
    final totalInches = goals.heightCm! / 2.54;
    _heightFeetController.text = (totalInches ~/ 12).toString();
    _heightInchesController.text = (totalInches % 12).round().toString();
  }
  // Convert goal weight kg → lb
  if (goals.goalWeightKg != null) {
    _goalWeightController.text = (goals.goalWeightKg! * 2.20462).toStringAsFixed(1);
  }
} else {
  _heightController.text = goals.heightCm?.toString() ?? '';
  _goalWeightController.text = goals.goalWeightKg?.toString() ?? '';
}
```

Use the same conversion logic as `_onUnitsChanged()` (lines 184-199) to stay consistent.

---

## Testing

### Manual test
1. Clear app data / reinstall
2. Complete onboarding in imperial mode with height 5'10" and weight 165 lb
3. Navigate to Goals tab
4. **Before fix:** height shows empty fields, goal weight shows ~74.8 (kg). Toggle metric→imperial to see correct values.
5. **After fix:** height shows "5" ft / "10" in, goal weight shows "165.0" lb immediately.

### Automated test ideas
- Widget test: create `UserGoal` with `useImperial: 1`, pump `GoalsScreen`, verify imperial height fields have expected text.
- Unit test: trace `_loadGoals` → verify correct controller population.

---

## Files to modify

- `lib/features/goals/goals_screen.dart` — `_loadGoals()` method
