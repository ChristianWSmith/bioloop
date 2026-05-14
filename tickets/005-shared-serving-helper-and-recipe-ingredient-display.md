# T5: Extract shared serving helper + fix recipe ingredient display

**Issue:** #2
**Effort:** ~15 min
**Dependencies:** None

## Context

### The display bug
In `recipe_ingredient_row.dart:27`, each ingredient renders as:

```
100.0 × g — 370 kcal
```

For per-100g foods where `food.servingLabel = "g"`, this looks ugly. The `.0` decimal on the quantity and the raw `×` symbol with the bare `"g"` label are confusing. It should display as:

```
100 g — 370 kcal
```

### The triplicated helper
Three files have identical `_buildLabel()` functions that format a quantity and unit into a clean string (rounding whole numbers):

| File | Line | Signature |
|------|------|-----------|
| `lib/features/logging/log_food_screen.dart` | 143 | `_buildLabel(double qty, String unit)` |
| `lib/features/logging/widgets/quick_food_log_sheet.dart` | 44 | `_buildLabel(double qty, String unit)` |
| `lib/features/logging/widgets/manual_food_form.dart` | 49 | `_buildLabel()` (reads from controllers) |

All implement the same logic:
```dart
String _buildLabel(double qty, String unit) {
  final qtyStr = qty == qty.roundToDouble()
      ? qty.toInt().toString()
      : qty.toStringAsFixed(1);
  return '$qtyStr $unit';
}
```

## Intent

1. Eliminate the triplicated `_buildLabel` by extracting a shared utility
2. Use the shared utility in `recipe_ingredient_row.dart` to display clean `"100 g — 370 kcal"` instead of `"100.0 × g — 370 kcal"`

## Changes

### New file: `lib/core/utils/serving_helpers.dart`

```dart
/// Formats a quantity and unit into a human-readable serving label.
/// Rounds to integer if the quantity is a whole number,
/// otherwise shows one decimal place.
String buildServingLabel(double quantity, String unit) {
  final qtyStr = quantity == quantity.roundToDouble()
      ? quantity.toInt().toString()
      : quantity.toStringAsFixed(1);
  return '$qtyStr $unit';
}
```

### Modified files

1. **`lib/features/logging/log_food_screen.dart`** — Remove inline `_buildLabel`, import and use `buildServingLabel`
2. **`lib/features/logging/widgets/quick_food_log_sheet.dart`** — Same
3. **`lib/features/logging/widgets/manual_food_form.dart`** — Same (replace the parameterless version with `buildServingLabel(qty, _unit)`)
4. **`lib/features/recipes/widgets/recipe_ingredient_row.dart`** — Use `buildServingLabel(ingredient.quantity, food.servingUnit)` instead of `'${ingredient.quantity.toStringAsFixed(1)} × ${food.servingLabel}'`

## Testing

- **Manual:** Add a per-100g food (e.g. white rice with `servingUnit = "g"`) as a recipe ingredient. Verify the ingredient row shows `"100 g — 370 kcal"` (not `"100.0 × g — 370 kcal"`). Log a food through all three paths (normal log, quick-log, manual food form) and verify serving labels are unchanged.
- **Unit test:** Test `buildServingLabel` directly with whole numbers (`buildServingLabel(100, "g") → "100 g"`), decimals (`buildServingLabel(2.5, "servings") → "2.5 servings"`), and edge cases (`buildServingLabel(0, "g") → "0 g"`).
- **Widget/regression tests:** Existing tests that check serving labels should continue to pass since the formatting logic is identical.
