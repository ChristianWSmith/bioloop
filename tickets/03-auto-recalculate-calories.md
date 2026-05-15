# Ticket 03 — Recalculate calories on every macro edit

**Issues**: #7  
**Phase**: 1  
**Dependencies**: None  
**Estimate**: ~20 minutes

---

## Context

`ManualFoodForm` has a `_caloriesManuallyEdited` flag that, once set
(user clicks into the calories field), permanently prevents auto-calculation
from macros. The user requested behavior: every macro field edit should
recalculate and overwrite the calories field. Direct calorie editing should
still work, but the next macro change overwrites it.

The `_settingCalories` guard already prevents infinite loops (calories
field's `onChanged` won't re-trigger `_autoComputeCalories`).

---

## Acceptance Criteria

1. Editing Protein/Carbs/Fat always recalculates calories via 4-4-9 rule.
2. User can manually type into the calories field.
3. After manually editing calories, the next change to any macro field
   overwrites the manual value with the computed value.
4. Clearing all three macro fields to zero does NOT clear calories (no
   special behavior needed for zero).
5. Existing tests are updated to reflect the new behavior.

---

## Implementation

**File**: `lib/features/logging/widgets/manual_food_form.dart`

### Remove the flag
- Delete `_caloriesManuallyEdited` field (line 31).
- Delete `if (_caloriesManuallyEdited) return;` check (line 102).
- Delete `if (!_settingCalories) _caloriesManuallyEdited = true;` in
  calories `onChanged` (line 274).
- Delete `_caloriesManuallyEdited = false;` in the `allZero` path (line 99) —
  the `allZero` early-return can stay or be removed (it only matters for
  empty-state behavior).

### Result
The method becomes:
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

---

## Testing

### Unit tests (`test/features/logging/manual_food_form_test.dart`)
- **Update**: The "manual override not overwritten" test should now verify
  the opposite — manually editing calories, then editing a macro, causes
  calories to be overwritten.
- **Keep**: The existing "auto-compute" test (20p+30c+10f = 290 cal).
- **Add**: Test that clearing macros doesn't crash or leave stale flag state.

### Manual tests
- Open "Create custom food"
- Enter Protein=20, Carbs=30, Fat=10
- **Verify**: Calories auto-fills as "290"
- Manually change calories to "999"
- Change Protein to 30
- **Verify**: Calories auto-updates to 330 (30×4 + 30×4 + 10×9)
- Enter all zeros for macros
- **Verify**: Calories field is NOT cleared (stays at last computed value)
- **Verify**: Save still works with all validations

---

## Files Changed

| File | Change |
|------|--------|
| `lib/features/logging/widgets/manual_food_form.dart` | Remove `_caloriesManuallyEdited` and its guard logic |
| `test/features/logging/manual_food_form_test.dart` | Update tests for new behavior |

---

## Open Questions

- Should the `allZero` early-return remain? With the flag removed, if all
  three macros are 0/null, `_autoComputeCalories` computes 0. The current
  early-return skips this. Either behavior is fine — keeping it avoids
  writing "0" to the calories field unnecessarily. Recommend keeping it.
