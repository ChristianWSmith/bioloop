# T2: Make auto-calc always overwrite calories

**Issue:** #7
**Effort:** ~5 min
**Dependencies:** None

## Context

In `ManualFoodForm` (`lib/features/logging/widgets/manual_food_form.dart`), when the user creates a custom food, calories are auto-computed from protein/carbs/fat using the 4-4-9 rule (`protein×4 + carbs×4 + fat×9`).

Current behaviour:
- User edits macros → calories auto-compute (correct)
- User edits the calories field directly → `_caloriesManuallyEdited = true`
- User subsequently edits macros → auto-compute is **permanently blocked**, calories field stays frozen
- Only way to re-enable: clear all three macro fields to empty/zero (undiscoverable)

Desired behaviour:
- User edits macros → calories auto-compute **always**, even if the user previously touched the calories field
- User can still edit calories directly between macro edits — the next macro change just overwrites it
- No complex state flags, no undiscoverable reset mechanism

## Intent

Make the calorie auto-compute predictable and simple: macros always drive the calorie calculation. Direct calorie edits are not persisted across macro edits.

## Changes

**File:** `lib/features/logging/widgets/manual_food_form.dart`

1. Remove the `_caloriesManuallyEdited` field (line 31) and all references to it
2. Remove the `allZero` reset block (lines 96-101) — no longer needed
3. Remove the `if (_caloriesManuallyEdited) return;` guard (line 102)
4. Remove the `onChanged` handler on the calories `TextField` that sets `_caloriesManuallyEdited` (line 274) — optionally replace with a no-op or remove entirely
5. Keep `_settingCalories` re-entrancy guard — this prevents infinite loops when the programmatic write to `_caloriesController.text` triggers `onChanged`

The simplified `_autoComputeCalories()`:
```dart
void _autoComputeCalories() {
  final p = double.tryParse(_proteinController.text);
  final c = double.tryParse(_carbsController.text);
  final f = double.tryParse(_fatController.text);
  if (p == null || c == null || f == null) return;
  if (p < 0 || c < 0 || f < 0) return;
  final computed = (p * 4) + (c * 4) + (f * 9);
  final text = computed == computed.roundToDouble()
      ? computed.toInt().toString()
      : computed.toStringAsFixed(1);
  _settingCalories = true;
  _caloriesController.text = text;
  _settingCalories = false;
}
```

## Testing

- **Manual:** Open the custom food form. Enter protein=20, carbs=30, fat=10. Verify calories show `290` (20×4 + 30×4 + 10×9 = 290). Edit calories to `999`. Change protein to 30. Verify calories recalculate to `330`. Clear all macros. Enter just protein=10. Verify calories update.
- **Widget test:** `ManualFoodForm` widget test — create a `ProviderScope` with in-memory DB. Fill macro fields programmatically, verify calories field. Edit calories field, change a macro, verify calories changed again.
