# Ticket 3: Fix edit entry quantity hint showing "100 g" instead of just "g"

**Issue:** #1  
**Priority:** Medium  
**Effort:** 2-3 lines  
**File:** `lib/features/logging/widgets/quick_food_log_sheet.dart`

## Context

When a food entry is logged via `QuickFoodLogSheet`, the `servingLabel` is set to the output of `_buildLabel(_servings, _unit)`, which constructs strings like `"100 g"` or `"3 servings"` (quantity + unit concatenated).

Later, when the entry is edited in `EditEntrySheet`, this `servingLabel` is displayed as the `suffixText` on the quantity `TextField`:

```dart
suffixText: widget.entry.servingLabel,
```

This shows `"100 g"` instead of just `"g"`. The user only needs to see the unit as a hint.

The `servingLabel` field on `FoodEntry` was originally intended to describe the serving unit (e.g., "g", "oz", "serving"). The `servings` field already stores the quantity. Including the quantity in the label is redundant and causes this display bug.

**Note:** This only affects entries logged *after* the fix. Previously-logged entries retain their full-format `servingLabel` strings. `EditEntrySheet` will display whatever is stored — no migration needed since old entries will still show the old format (acceptable transitional state).

## Acceptance criteria

- [ ] Logging a food via quick-log → `servingLabel` saved as just the unit (e.g., `"g"`, `"oz"`, `"serving"`)
- [ ] Editing that entry → quantity suffix shows just the unit (e.g., `"g"`)
- [ ] Existing entries logged before this fix still display (old `servingLabel` format still shows in edit, may show old format — acceptable)
- [ ] `_buildLabel` is removed or simplified (dead code elimination)

## Testing

### Manual testing
1. Log a per-100g food via the search FAB → quick-log → save
2. Tap the entry in today's list to edit → verify the quantity suffix shows `"g"` (not `"100 g"`)
3. Log a food with unit "servings" → edit → verify suffix shows `"servings"` (not `"3 servings"`)
4. Check an older entry (logged before this fix) → edit → may show old format, but no crash

### Regression checks
- The `servingLabel` column in `food_entries` is a text field used only for display in `EditEntrySheet`. No queries filter or join on it.
- The `_buildLabel` method is only called in one place (line 87). After removal, nothing else references it.
- The `ServingSizePicker` still works correctly (it has its own internal `_buildLabel`-like logic in `initState` for display, not for persistence).

## Implementation

```dart
// lib/features/logging/widgets/quick_food_log_sheet.dart:87
// Before:
servingLabel: _buildLabel(_servings, _unit),
// After:
servingLabel: _unit,
```

Then remove the `_buildLabel` method (lines 44-49):

```dart
// Remove this entire method
String _buildLabel(double qty, String unit) {
  final qtyStr = qty == qty.roundToDouble()
      ? qty.toInt().toString()
      : qty.toStringAsFixed(1);
  return '$qtyStr $unit';
}
```
