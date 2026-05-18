# F1: Format whole number quantities without ".0" suffix

**Category**: Food Logging / Recipes
**Priority**: Low
**Estimated effort**: Small (3 files, 4 locations)
**Discovery**: `DISCOVERY.md` → F1

## Problem

When logging or editing food/recipe entries, whole numbers display with a trailing `.0` (e.g. "100.0" instead of "100"). This adds unnecessary friction — users must delete the `.0` before submitting.

## Root Cause

The app already has a consistent "smart formatting" pattern used in `ServingSizePicker` and `RecipeIngredientRow`:

```dart
value == value.roundToDouble() ? value.toInt().toString() : value.toStringAsFixed(1)
```

But four locations use `.toStringAsFixed(1)` or `.toString()` instead:

| File | Line | Context | Current | Displays "100.0" as |
|---|---|---|---|---|
| `edit_entry_sheet.dart` | 39 | Servings controller init | `e.servings.toStringAsFixed(1)` | `"100.0"` |
| `recipe_form_screen.dart` | 89 | Add ingredient default | `food.servingQuantity.toString()` | `"100.0"` |
| `recipe_form_screen.dart` | 130 | Edit ingredient default | `item.ingredient.quantity.toStringAsFixed(1)` | `"100.0"` |
| `manual_food_form.dart` | 40 | Existing food quantity | `food.servingQuantity.toString()` | `"100.0"` |

### Already correct (reference implementations)

| File | Location |
|---|---|
| `serving_size_picker.dart` | `initState` (line 35-39) and `didUpdateWidget` (line 45-49) |
| `recipe_ingredient_row.dart` | `_ingredientSubtitle()` (line 48-50) |
| `manual_food_form.dart` | `_buildLabel()` (line 68-72) |

## Proposed Fix

Apply the smart formatting pattern at each of the 4 locations:

### `edit_entry_sheet.dart:38-39`
```dart
// Before
_servingsController = TextEditingController(
    text: e.servings.toStringAsFixed(1));

// After
_servingsController = TextEditingController(
    text: _formatQuantity(e.servings));
```

### `recipe_form_screen.dart:89`
```dart
// Before
initialValue: food.servingQuantity.toString(),

// After
initialValue: _formatQuantity(food.servingQuantity),
```

### `recipe_form_screen.dart:130`
```dart
// Before
initialValue: item.ingredient.quantity.toStringAsFixed(1),

// After
initialValue: _formatQuantity(item.ingredient.quantity),
```

### `manual_food_form.dart:40`
```dart
// Before
_qtyController.text = food.servingQuantity.toString();

// After
_qtyController.text = _formatQuantity(food.servingQuantity);
```

Optionally extract a shared helper function to avoid repetition:
```dart
String _formatQuantity(double value) =>
    value == value.roundToDouble() ? value.toInt().toString() : value.toStringAsFixed(1);
```

## Acceptance Criteria

- [ ] Edit entry sheet: whole number servings display without ".0" (e.g. "100" not "100.0")
- [ ] Recipe form: adding an ingredient with whole quantity shows without ".0"
- [ ] Recipe form: editing an ingredient with whole quantity shows without ".0"
- [ ] Manual food form: editing existing food with whole quantity shows without ".0"
- [ ] Fractional values still display correctly (e.g. "100.5" not "100" or "100.50")
- [ ] Internal data model remains `double` — no changes to storage or calculation logic
- [ ] `flutter analyze` passes with zero issues

## Testing

### Manual testing — Edit entry
1. Log a food with servingQuantity=100
2. Tap the entry to edit
3. Verify the quantity field shows "100" (not "100.0")
4. Change to a fractional value (e.g. 100.5) → verify it shows "100.5"

### Manual testing — Recipe ingredients
1. Create a recipe, add an ingredient with quantity=100
2. Verify the quantity dialog shows "100" (not "100.0")
3. Edit the ingredient → verify it shows "100"

### Manual testing — Manual food form
1. Create a custom food with quantity=100
2. Edit the food
3. Verify the quantity field shows "100" (not "100.0")

### Edge cases
- Quantity = 1.0 → shows "1"
- Quantity = 0.5 → shows "0.5"
- Quantity = 100.0 → shows "100"
- Quantity = 100.5 → shows "100.5"
- Quantity = 100.55 (if somehow stored) → shows "100.6" (1 decimal)

## Files to change

| File | Lines | Change |
|---|---|---|
| `lib/features/history/widgets/edit_entry_sheet.dart` | 38-39 | Smart format servings |
| `lib/features/recipes/recipe_form_screen.dart` | 89 | Smart format add ingredient |
| `lib/features/recipes/recipe_form_screen.dart` | 130 | Smart format edit ingredient |
| `lib/features/logging/widgets/manual_food_form.dart` | 40 | Smart format existing food |

## References

- `lib/features/logging/widgets/serving_size_picker.dart:35-39` — reference implementation
- `lib/features/recipes/widgets/recipe_ingredient_row.dart:48-50` — reference implementation
